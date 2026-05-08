"""Registry CRUD — thread-safe session state management."""

import json
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from .utils import logger, run


class SessionManager:
    def __init__(self, state_dir: Path):
        self.registry_path = state_dir / "registry.json"
        self._lock = threading.Lock()

    def load(self) -> dict:
        with self._lock:
            return self._load_unsafe()

    def _load_unsafe(self) -> dict:
        if not self.registry_path.exists():
            return {}
        try:
            with open(self.registry_path) as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            logger.warning("Corrupt registry, starting fresh")
            return {}

    def save(self, registry: dict) -> None:
        with self._lock:
            self._save_unsafe(registry)

    def _save_unsafe(self, registry: dict) -> None:
        tmp = self.registry_path.with_suffix(".tmp")
        with open(tmp, "w") as f:
            json.dump(registry, f, indent=2)
        tmp.rename(self.registry_path)

    def get_active_sessions(self) -> dict[str, dict]:
        reg = self.load()
        return {k: v for k, v in reg.items() if v.get("status") == "active"}

    def register(self, key: str, entry: dict) -> None:
        with self._lock:
            reg = self._load_unsafe()
            reg[key] = entry
            self._save_unsafe(reg)

    def close_session(self, key: str) -> None:
        self.update_field(key, "status", "closed")

    def remove_session(self, key: str) -> None:
        with self._lock:
            reg = self._load_unsafe()
            reg.pop(key, None)
            self._save_unsafe(reg)

    def find_by_thread(self, thread_ts: str) -> tuple[str, dict] | None:
        for k, v in self.load().items():
            if v.get("thread_ts") == thread_ts and v.get("status") == "active":
                return k, v
        return None

    def find_by_tmux(self, tmux_session: str) -> tuple[str, dict] | None:
        for k, v in self.load().items():
            if v.get("tmux_session") == tmux_session and v.get("status") == "active":
                return k, v
        return None

    def update_field(self, key: str, field: str, value: Any) -> None:
        with self._lock:
            reg = self._load_unsafe()
            if key in reg:
                reg[key][field] = value
                self._save_unsafe(reg)

    def cleanup_dead_sessions(self) -> list[str]:
        closed = []
        with self._lock:
            reg = self._load_unsafe()
            for k, v in reg.items():
                if v.get("status") != "active":
                    continue
                tmux = v.get("tmux_session", k)
                result = run(f"tmux has-session -t {tmux} 2>/dev/null")
                if result.returncode != 0:
                    v["status"] = "closed"
                    closed.append(k)
            if closed:
                self._save_unsafe(reg)
        return closed

    def trim_old_closed(self, days: int = 7) -> int:
        cutoff = datetime.utcnow() - timedelta(days=days)
        removed = 0
        with self._lock:
            reg = self._load_unsafe()
            to_remove = []
            for k, v in reg.items():
                if v.get("status") in ("closed",) and v.get("started_at"):
                    try:
                        started = datetime.fromisoformat(v["started_at"].replace("Z", "+00:00"))
                        if started.replace(tzinfo=None) < cutoff:
                            to_remove.append(k)
                    except ValueError:
                        pass
            for k in to_remove:
                del reg[k]
                removed += 1
            if removed:
                self._save_unsafe(reg)
        return removed
