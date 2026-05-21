"""Message routing — TUI detection + tmux send-keys."""

import re
import time
from pathlib import Path

from .config import Config
from .sessions import SessionManager
from .utils import logger, run


# TUI prompt patterns
TUI_PATTERNS = [
    re.compile(r"Do you want to proceed"),
    re.compile(r"❯\s+\d+\."),
    re.compile(r"Enter to confirm"),
    re.compile(r"Esc to cancel"),
]

INPUT_PROMPT_PATTERN = re.compile(r"-- INSERT --")
PROMPT_INDICATOR = re.compile(r"^❯\s*$", re.MULTILINE)


class MessageRouter:
    def __init__(self, config: Config, sessions: SessionManager):
        self.config = config
        self.sessions = sessions

    def route_message(self, key: str, entry: dict, text: str) -> None:
        tmux = entry.get("tmux_session", key)
        pane = self.capture_pane(tmux)
        state = self.detect_state(pane)

        # Reset prompt flag and mark that we're waiting for a response
        self.sessions.update_field(key, "prompt_forwarded", False)
        self.sessions.update_field(key, "waiting_response", True)

        if state == "tui_prompt":
            self.send_tui_response(tmux, text)
            self.sessions.update_field(key, "needs_slack_nudge", True)
        elif state == "input_prompt":
            self.send_text_input(tmux, text)
        else:
            # Worker is busy — send anyway, tmux buffers it
            self.send_text_input(tmux, text)

    def capture_pane(self, tmux_session: str, lines: int = 15) -> str:
        result = run(f"tmux capture-pane -t {tmux_session} -p 2>/dev/null")
        if result.returncode != 0:
            return ""
        output_lines = result.stdout.strip().split("\n")
        return "\n".join(output_lines[-lines:])

    def detect_state(self, pane_text: str) -> str:
        if any(p.search(pane_text) for p in TUI_PATTERNS):
            return "tui_prompt"
        if INPUT_PROMPT_PATTERN.search(pane_text) and PROMPT_INDICATOR.search(pane_text):
            return "input_prompt"
        return "busy"

    def send_tui_response(self, tmux_session: str, text: str) -> None:
        lower = text.strip().lower()

        if lower in ("1", "yes", "y"):
            run(f"tmux send-keys -t {tmux_session} Enter")
        elif lower in ("2", "no", "n"):
            run(f"tmux send-keys -t {tmux_session} Down Enter")
        elif lower == "3":
            run(f"tmux send-keys -t {tmux_session} Down Down Enter")
        elif lower.startswith("amend:"):
            amended = text[6:].strip()
            run(f"tmux send-keys -t {tmux_session} Tab")
            time.sleep(1)
            run(f"tmux send-keys -t {tmux_session} '{self._escape(amended)}' Enter")
        elif lower == "explain":
            run(f"tmux send-keys -t {tmux_session} C-e")
        elif lower in ("cancel", "esc"):
            run(f"tmux send-keys -t {tmux_session} Escape")
        else:
            # Unknown TUI input — try sending Enter (safe default)
            run(f"tmux send-keys -t {tmux_session} Enter")

    def send_text_input(self, tmux_session: str, text: str) -> None:
        # Always use temp file to avoid shell escaping issues
        tmp = Path(f"/tmp/slack-input-{tmux_session}.txt")
        tmp.write_text(text)
        run(f'tmux send-keys -t {tmux_session} "$(cat {tmp})" Enter')
        # Extra Enter in case paste protection triggers
        time.sleep(0.5)
        run(f"tmux send-keys -t {tmux_session} Enter")

    def _escape(self, text: str) -> str:
        return text.replace("'", "'\\''")
