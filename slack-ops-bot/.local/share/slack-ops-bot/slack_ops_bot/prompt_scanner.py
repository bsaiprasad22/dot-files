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

            # Check for nudge needed (after TUI answer was routed)
            elif entry.get("needs_slack_nudge"):
                state = self.router.detect_state(self._capture(tmux, 15))
                if state != "tui_prompt":
                    # Prompt was resolved — no nudge needed, Stop hook will handle it
                    self.sessions.update_field(key, "needs_slack_nudge", False)

    def _capture(self, tmux_session: str, lines: int) -> str:
        result = run(f"tmux capture-pane -t {tmux_session} -p 2>/dev/null")
        if result.returncode != 0:
            return ""
        output = result.stdout.strip().split("\n")
        return "\n".join(output[-lines:])

    def _forward_prompt(self, key: str, entry: dict, pane_text: str) -> None:
        msg = f"*{key}* is waiting for input:\n```\n{truncate(pane_text, 2500)}\n```\nReply `1` = Yes, `2` = No (or `3` if shown)"
        self.client.chat_postMessage(
            channel=entry["channel_id"],
            thread_ts=entry["thread_ts"],
            text=msg,
        )
        logger.info(f"Forwarded prompt for {key}")
