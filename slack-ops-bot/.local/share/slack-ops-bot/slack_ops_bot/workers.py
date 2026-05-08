"""Worker session spawning — tmux + worktree management."""

import tempfile
import time
import threading
from datetime import datetime
from pathlib import Path

from .config import Config
from .sessions import SessionManager
from .utils import logger, run, sanitize_session_name


class WorkerManager:
    def __init__(self, config: Config, sessions: SessionManager):
        self.config = config
        self.sessions = sessions

    def spawn_worker(
        self,
        session_name: str,
        jira_id: str | None,
        task_description: str,
        thread_ts: str,
        channel_id: str,
    ) -> bool:
        session_name = sanitize_session_name(session_name)

        # Check if tmux session already exists — connect instead of spawn
        if self.tmux_session_exists(session_name):
            return self.connect_existing(session_name, thread_ts, channel_id)

        # Create worktree if Jira ID provided
        work_dir = Path.home()
        if jira_id:
            wt = self._create_worktree(jira_id)
            if wt:
                work_dir = wt

        # Spawn tmux session
        result = run(f"tmux new-session -d -s {session_name} -c {work_dir}")
        if result.returncode != 0:
            logger.error(f"Failed to create tmux session {session_name}: {result.stderr}")
            return False

        # Start Claude in the session
        run(f"tmux send-keys -t {session_name} 'claude' Enter")

        # Register in registry
        self.sessions.register(session_name, {
            "thread_ts": thread_ts,
            "channel_id": channel_id,
            "tmux_session": session_name,
            "jira_id": jira_id,
            "status": "active",
            "task_description": task_description,
            "started_at": datetime.utcnow().isoformat() + "Z",
            "last_thread_ts_seen": thread_ts,
            "source": "slack",
        })

        # Send initial prompt in background (wait for Claude to start)
        prompt = self._build_initial_prompt(jira_id, task_description)
        threading.Thread(
            target=self._send_initial_prompt,
            args=(session_name, prompt),
            daemon=True,
        ).start()

        return True

    def connect_existing(
        self,
        session_name: str,
        thread_ts: str,
        channel_id: str,
    ) -> bool:
        if not self.tmux_session_exists(session_name):
            return False

        self.sessions.register(session_name, {
            "thread_ts": thread_ts,
            "channel_id": channel_id,
            "tmux_session": session_name,
            "jira_id": None,
            "status": "active",
            "task_description": "Connected existing session",
            "started_at": datetime.utcnow().isoformat() + "Z",
            "last_thread_ts_seen": thread_ts,
            "source": "terminal",
        })
        return True

    def kill_worker(self, session_key: str) -> dict:
        cleaned = []
        entry = self.sessions.load().get(session_key, {})
        tmux = entry.get("tmux_session", session_key)
        jira_id = entry.get("jira_id")

        # Kill tmux session
        result = run(f"tmux kill-session -t {tmux} 2>/dev/null")
        if result.returncode == 0:
            cleaned.append("tmux session")

        # Remove temp files
        for pattern in [f"/tmp/slack-prompt-{session_key}.txt",
                        f"/tmp/slack-input-{session_key}.txt"]:
            p = Path(pattern)
            if p.exists():
                p.unlink()
                cleaned.append(p.name)

        # Remove worktree if Jira-linked
        if jira_id:
            wt_path = f"{self.config.worktree_base}/{jira_id}"
            run(f"git -C {self.config.default_project_dir} worktree remove {wt_path} --force 2>/dev/null")
            run(f"git -C {self.config.default_project_dir} branch -D {jira_id} 2>/dev/null")
            cleaned.append("worktree")

        # Remove from registry
        self.sessions.remove_session(session_key)
        cleaned.append("registry entry")

        return {"cleaned": cleaned}

    def tmux_session_exists(self, name: str) -> bool:
        return run(f"tmux has-session -t {name} 2>/dev/null").returncode == 0

    def list_tmux_sessions(self) -> list[dict]:
        result = run("tmux list-sessions -F '#{session_name}|#{session_created}|#{?session_attached,attached,detached}' 2>/dev/null")
        if result.returncode != 0:
            return []
        sessions = []
        for line in result.stdout.strip().split("\n"):
            if not line or line.startswith("claude-ops"):
                continue
            parts = line.split("|")
            if len(parts) >= 3:
                sessions.append({
                    "name": parts[0],
                    "created": parts[1],
                    "state": parts[2],
                })
        return sessions

    def _create_worktree(self, jira_id: str) -> Path | None:
        wt_path = Path(self.config.worktree_base) / jira_id
        if wt_path.exists():
            return wt_path
        result = run(
            f"git -C {self.config.default_project_dir} worktree add {wt_path} -b {jira_id} main 2>&1"
        )
        if result.returncode != 0:
            logger.warning(f"Worktree creation failed: {result.stdout}")
            return None
        return wt_path

    def _send_initial_prompt(self, session_name: str, prompt: str) -> None:
        # Wait for Claude to start (check for INSERT mode)
        for _ in range(20):
            time.sleep(3)
            result = run(f"tmux capture-pane -t {session_name} -p 2>/dev/null")
            if "INSERT" in result.stdout:
                break
        else:
            logger.warning(f"Claude didn't start in {session_name} within 60s")
            return

        # Write prompt to temp file to avoid paste protection
        tmp = Path(f"/tmp/slack-prompt-{session_name}.txt")
        tmp.write_text(prompt)
        run(f'tmux send-keys -t {session_name} "$(cat {tmp})" Enter')
        time.sleep(1)
        run(f"tmux send-keys -t {session_name} Enter")

    def _build_initial_prompt(self, jira_id: str | None, task: str) -> str:
        context = f"Jira task {jira_id}" if jira_id else "an ad-hoc task"
        return f"""You are working on {context}.

Task: {task}

Instructions:
- Follow all CLAUDE.md conventions (TDD, commit format, private remote, etc.)
- Your responses will be automatically forwarded to a Slack thread
- When done, summarize: files changed, approach taken, PR link"""
