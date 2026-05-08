"""Command parsing for Slack messages."""

import re
from dataclasses import dataclass


@dataclass
class ParsedCommand:
    type: str  # "task", "list", "close", "kill"
    session_name: str | None = None
    jira_id: str | None = None
    description: str | None = None


_BRACKET_RE = re.compile(r"\[([^\]]+)\]")
_JIRA_RE = re.compile(r"\b([A-Z]+-\d+)\b")


def parse(text: str) -> ParsedCommand:
    """Parse top-level @mention text into a command."""
    text = text.strip()
    lower = text.lower()

    if lower in ("list", "sessions"):
        return ParsedCommand(type="list")

    # "connect <session_name>" — connect to existing tmux session
    if lower.startswith("connect "):
        name = text[8:].strip()
        return ParsedCommand(type="task", session_name=name, description=f"Connect to {name}")

    # Extract optional [session_name]
    session_name = None
    bracket_match = _BRACKET_RE.search(text)
    if bracket_match:
        session_name = bracket_match.group(1).strip()
        text = text[:bracket_match.start()] + text[bracket_match.end():]
        text = text.strip()

    # Extract optional Jira ID
    jira_id = None
    jira_match = _JIRA_RE.search(text)
    if jira_match:
        jira_id = jira_match.group(1)
        text = text[:jira_match.start()] + text[jira_match.end():]
        text = text.strip()

    description = text if text else None

    return ParsedCommand(
        type="task",
        session_name=session_name,
        jira_id=jira_id,
        description=description,
    )


def parse_thread_command(text: str) -> str | None:
    """Check if a thread reply is a close/kill command."""
    lower = text.strip().lower()
    # Match with or without @mention prefix
    lower = re.sub(r"@\w+\s*", "", lower).strip()
    if lower in ("close", "disconnect"):
        return "close"
    if lower in ("kill", "terminate"):
        return "kill"
    return None


def extract_session_name(text: str) -> str | None:
    m = _BRACKET_RE.search(text)
    return m.group(1).strip() if m else None


def extract_jira_id(text: str) -> str | None:
    m = _JIRA_RE.search(text)
    return m.group(1) if m else None
