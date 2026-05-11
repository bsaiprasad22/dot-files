"""Watch for pending-* files and process them."""

import json
from pathlib import Path

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from .config import Config
from .sessions import SessionManager
from .utils import logger, truncate


class PendingFileHandler(FileSystemEventHandler):
    def __init__(self, config: Config, sessions: SessionManager, slack_client):
        self.config = config
        self.sessions = sessions
        self.client = slack_client

    def on_created(self, event):
        if event.is_directory:
            return
        path = Path(event.src_path)
        try:
            if path.name.startswith("pending-response-"):
                self._handle_response(path)
            elif path.name.startswith("pending-prompt-"):
                self._handle_prompt(path)
            elif path.name.startswith("pending-connect-"):
                self._handle_connect(path)
        except Exception as e:
            logger.error(f"Error handling {path.name}: {e}")

    def _handle_response(self, path: Path) -> None:
        # Extract session name: pending-response-<name>.txt
        session_name = path.stem.replace("pending-response-", "")
        result = self.sessions.find_by_tmux(session_name)
        if not result:
            logger.debug(f"No active session for {session_name}, skipping response")
            path.unlink(missing_ok=True)
            return

        key, entry = result
        response = path.read_text().strip()
        if not response:
            path.unlink(missing_ok=True)
            return

        # Set flag so prompt scanner doesn't also forward this
        self.sessions.update_field(key, "prompt_forwarded", True)

        self.client.chat_postMessage(
            channel=entry["channel_id"],
            thread_ts=entry["thread_ts"],
            text=truncate(response),
        )
        path.unlink(missing_ok=True)
        logger.info(f"Posted response for {session_name}")

    def _handle_prompt(self, path: Path) -> None:
        session_name = path.stem.replace("pending-prompt-", "")
        result = self.sessions.find_by_tmux(session_name)
        if not result:
            path.unlink(missing_ok=True)
            return

        key, entry = result
        try:
            prompt_data = json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            path.unlink(missing_ok=True)
            return

        tool = prompt_data.get("tool_name", "unknown")
        cmd = prompt_data.get("command", "")
        desc = prompt_data.get("description", "")

        # Set flag so prompt scanner doesn't also forward this
        self.sessions.update_field(key, "prompt_forwarded", True)

        msg = f"*{session_name}* needs permission:\nTool: `{tool}`\nCommand: `{cmd}`"
        if desc:
            msg += f"\n{desc}"
        msg += "\nReply `1` = Yes, `2` = No"

        self.client.chat_postMessage(
            channel=entry["channel_id"],
            thread_ts=entry["thread_ts"],
            text=msg,
        )
        path.unlink(missing_ok=True)
        logger.info(f"Forwarded prompt for {session_name}")

    def _handle_connect(self, path: Path) -> None:
        try:
            data = json.loads(path.read_text())
        except (json.JSONDecodeError, OSError):
            path.unlink(missing_ok=True)
            return

        from .workers import WorkerManager
        tmux_session = data.get("tmux_session", "")
        branch = data.get("branch", "none")
        cwd = data.get("cwd", "~")

        # Post to channel to create thread
        resp = self.client.chat_postMessage(
            channel=self.config.channel_id,
            text=f"Connected session `{tmux_session}` (branch: `{branch}`, dir: `{cwd}`)",
        )
        thread_ts = resp["ts"]

        # Register
        from .workers import WorkerManager
        self.sessions.register(tmux_session, {
            "thread_ts": thread_ts,
            "channel_id": self.config.channel_id,
            "tmux_session": tmux_session,
            "jira_id": None,
            "status": "active",
            "task_description": f"Connected from terminal ({cwd})",
            "started_at": data.get("requested_at", ""),
            "last_thread_ts_seen": thread_ts,
            "source": "terminal",
        })

        path.unlink(missing_ok=True)
        logger.info(f"Connected session {tmux_session}")


def start_watcher(config: Config, sessions: SessionManager, slack_client) -> Observer:
    handler = PendingFileHandler(config, sessions, slack_client)
    observer = Observer()
    observer.schedule(handler, str(config.state_dir), recursive=False)
    observer.start()
    logger.info(f"File watcher started on {config.state_dir}")
    return observer
