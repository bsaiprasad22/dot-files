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


def clean_for_slack(text: str) -> str:
    """Clean terminal output for Slack-friendly formatting."""
    # Strip ANSI escape codes
    text = re.sub(r"\x1b\[[0-9;]*[a-zA-Z]", "", text)
    text = re.sub(r"\x1b\].*?\x07", "", text)  # OSC sequences

    # Convert box-drawing tables to simple pipe tables
    text = text.replace("┌", "+").replace("┐", "+").replace("└", "+").replace("┘", "+")
    text = text.replace("├", "+").replace("┤", "+").replace("┼", "+")
    text = text.replace("─", "-").replace("│", "|")
    text = text.replace("╌", "-")

    lines = text.split("\n")
    clean = []
    for line in lines:
        stripped = line.strip()

        # Skip pure separator lines (all dashes/pluses)
        if stripped and all(c in "+-| " for c in stripped):
            continue

        # Skip Claude UI chrome
        if stripped.startswith("╭") or stripped.startswith("╰"):
            continue
        if "-- INSERT --" in stripped or "bypass permissions" in stripped:
            continue
        if stripped.startswith("dir:") or stripped.startswith("model:"):
            continue
        if stripped.startswith("❯") and len(stripped) <= 2:
            continue
        if stripped.startswith("✻") or stripped.startswith("✶") or stripped.startswith("✽"):
            continue
        if stripped.startswith("※ recap:"):
            continue
        if "ctrl+o to expand" in stripped:
            continue
        if stripped.startswith("Tip:") or stripped.startswith("Welcome"):
            continue
        if "Cooked for" in stripped or "Baked for" in stripped or "Brewed for" in stripped:
            continue
        if "MCP server needs auth" in stripped:
            continue

        # Clean Claude markers
        line = re.sub(r"^[●○◆◇▸▹⎿]\s*", "", line)
        line = re.sub(r"^★ Insight.*$", "", line)
        line = re.sub(r"^─+$", "", line)

        if line.strip():
            clean.append(line)

    result = "\n".join(clean).strip()

    # Collapse multiple blank lines
    result = re.sub(r"\n{3,}", "\n\n", result)

    # Convert markdown-style formatting to Slack mrkdwn
    # **bold** → *bold*  (Slack uses single asterisk for bold)
    result = re.sub(r"\*\*(.+?)\*\*", r"*\1*", result)

    # Wrap tool output blocks (lines starting with Bash(...), Read(...), etc.) in code blocks
    tool_pattern = re.compile(r"^(Bash|Read|Write|Edit|Glob|Grep|Slacked)\(", re.MULTILINE)
    if tool_pattern.search(result):
        # Has tool calls — wrap each tool line in backticks
        lines = result.split("\n")
        formatted = []
        for line in lines:
            if tool_pattern.match(line.strip()):
                formatted.append(f"`{line.strip()}`")
            else:
                formatted.append(line)
        result = "\n".join(formatted)

    return result


def run(cmd: str | list[str], timeout: int = 30) -> subprocess.CompletedProcess:
    if isinstance(cmd, str):
        return subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=timeout)
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
