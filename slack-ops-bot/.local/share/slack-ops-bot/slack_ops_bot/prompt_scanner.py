"""Periodic tmux pane scanner for stuck prompts and idle output."""

import hashlib
import threading

from .config import Config
from .routing import MessageRouter, TUI_PATTERNS
from .sessions import SessionManager
from .utils import logger, run, truncate


class PromptScanner:
    def __init__(
        self,
        config: Config,
        sessions: SessionManager,
        slack_client,
        router: MessageRouter,
        interval: float = 5.0,
    ):
        self.config = config
        self.sessions = sessions
        self.client = slack_client
        self.router = router
        self.interval = interval
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()
        logger.info(f"Prompt scanner started ({self.interval}s interval)")

    def stop(self) -> None:
        self._stop.set()

    def _loop(self) -> None:
        while not self._stop.is_set():
            try:
                self._scan()
            except Exception as e:
                logger.error(f"Prompt scan error: {e}")
            self._stop.wait(self.interval)

    def _scan(self) -> None:
        active = self.sessions.get_active_sessions()
        dead = self.sessions.cleanup_dead_sessions()
        if dead:
            logger.info(f"Cleaned dead sessions: {dead}")

        for key, entry in active.items():
            tmux = entry.get("tmux_session", key)
            pane = self._capture(tmux, 40)
            if not pane:
                continue

            # Check for stuck permission prompts
            if any(p.search(pane) for p in TUI_PATTERNS):
                prompt_hash = hashlib.md5(pane.encode()).hexdigest()[:8]
                last = entry.get("last_forwarded_prompt")
                if last != prompt_hash:
                    self._forward_prompt(key, entry, pane)
                    self.sessions.update_field(key, "last_forwarded_prompt", prompt_hash)

            # Check for idle worker at input prompt — forward output as safety net
            elif self.router.detect_state(pane) == "input_prompt":
                pane_hash = hashlib.md5(pane.encode()).hexdigest()[:8]
                last_idle = entry.get("last_idle_capture")
                if last_idle != pane_hash:
                    # New idle state — worker finished a response but Stop hook
                    # didn't fire (old session or hook not loaded). Forward output.
                    self._forward_idle_output(key, entry, pane)
                    self.sessions.update_field(key, "last_idle_capture", pane_hash)

            # Clear nudge flag if prompt was resolved
            if entry.get("needs_slack_nudge"):
                state = self.router.detect_state(self._capture(tmux, 15))
                if state != "tui_prompt":
                    self.sessions.update_field(key, "needs_slack_nudge", False)

    def _capture(self, tmux_session: str, lines: int) -> str:
        result = run(f"tmux capture-pane -t {tmux_session} -p 2>/dev/null")
        if result.returncode != 0:
            return ""
        output = result.stdout.strip().split("\n")
        return "\n".join(output[-lines:])

    def _forward_idle_output(self, key: str, entry: dict, pane_text: str) -> None:
        # Extract the last Claude response — text between the last two ❯ prompts
        lines = pane_text.strip().split("\n")
        # Find lines that are Claude's output (not status bars, not prompts)
        output_lines = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("❯") or stripped.startswith("dir:") or "-- INSERT --" in stripped:
                continue
            if stripped.startswith("────"):
                continue
            output_lines.append(line)
        output = "\n".join(output_lines).strip()
        if not output:
            return
        msg = f"*{key}*:\n{truncate(output, 3000)}"
        self.client.chat_postMessage(
            channel=entry["channel_id"],
            thread_ts=entry["thread_ts"],
            text=msg,
        )
        logger.info(f"Forwarded idle output for {key}")

    def _forward_prompt(self, key: str, entry: dict, pane_text: str) -> None:
        msg = f"*{key}* is waiting for input:\n```\n{truncate(pane_text, 2500)}\n```\nReply `1` = Yes, `2` = No (or `3` if shown)"
        self.client.chat_postMessage(
            channel=entry["channel_id"],
            thread_ts=entry["thread_ts"],
            text=msg,
        )
        logger.info(f"Forwarded prompt for {key}")
