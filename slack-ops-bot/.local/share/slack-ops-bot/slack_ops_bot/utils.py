"""Shared utilities."""

import logging
import re
import subprocess

logger = logging.getLogger("slack-ops-bot")


def setup_logging(level: str = "INFO") -> None:
    logging.basicConfig(
        level=getattr(logging, level.upper(), logging.INFO),
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )


def truncate(text: str, max_len: int = 3500) -> str:
    if len(text) <= max_len:
        return text
    return text[:max_len] + "\n... [truncated]"


def strip_mention(text: str, bot_id: str = "") -> str:
    """Remove <@BOT_ID> prefix from event text."""
    text = re.sub(r"<@[A-Z0-9]+>\s*", "", text).strip()
    return text


def generate_session_key(ts: str) -> str:
    return f"query-{ts.replace('.', '')[-6:]}"


def sanitize_session_name(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]", "_", name)


def run(cmd: str | list[str], timeout: int = 30) -> subprocess.CompletedProcess:
    if isinstance(cmd, str):
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
