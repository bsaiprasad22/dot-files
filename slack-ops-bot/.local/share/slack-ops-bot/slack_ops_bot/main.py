"""Slack-ops bot — polling-based entry point.

Uses user token (from MCP OAuth) to read channels/threads.
Uses bot token to post responses (bot identity = push notifications).
"""

import signal
import sys
import time
import re

from slack_sdk import WebClient

from .commands import parse, parse_thread_command
from .config import Config
from .file_watcher import start_watcher
from .jira import JiraClient
from .prompt_scanner import PromptScanner
from .routing import MessageRouter
from .sessions import SessionManager
from .utils import generate_session_key, logger, setup_logging, strip_mention, truncate
from .workers import WorkerManager

KEYWORD_RE = re.compile(r"@claude\b", re.IGNORECASE)


def main() -> None:
    setup_logging()
    logger.info("Loading config...")

    config = Config.load()
    errors = config.validate()
    if errors:
        for e in errors:
            logger.error(e)
        sys.exit(1)

    # Two clients: user for reading, bot for posting
    reader = WebClient(token=config.slack_user_token)
    poster = WebClient(token=config.slack_bot_token)

    logger.info(f"Channel: {config.channel_id}, Poll: {config.poll_interval}s")

    # Verify tokens
    try:
        bot_info = poster.auth_test()
        logger.info(f"Bot: {bot_info['user']} (ID: {bot_info['user_id']})")
        bot_id = bot_info["user_id"]
    except Exception as e:
        logger.error(f"Bot token invalid: {e}")
        sys.exit(1)

    try:
        reader.conversations_history(channel=config.channel_id, limit=1)
        logger.info("User token verified — can read channel")
    except Exception as e:
        logger.error(f"User token can't read channel: {e}")
        sys.exit(1)

    # Initialize components
    sessions = SessionManager(config.state_dir)
    workers = WorkerManager(config, sessions)
    router = MessageRouter(config, sessions)
    jira_client = JiraClient(config)

    # Start file watcher
    observer = start_watcher(config, sessions, poster)

    # Start prompt scanner
    scanner = PromptScanner(config, sessions, poster, router, config.prompt_scan_interval)
    scanner.start()

    # Cleanup on startup
    dead = sessions.cleanup_dead_sessions()
    if dead:
        logger.info(f"Cleaned stale sessions: {dead}")
    trimmed = sessions.trim_old_closed()
    if trimmed:
        logger.info(f"Trimmed {trimmed} old entries")

    # Track last seen channel message
    last_channel_ts = "0"

    # Graceful shutdown
    running = True
    def shutdown(sig, frame):
        nonlocal running
        logger.info("Shutting down...")
        running = False

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    logger.info("Polling started.")

    while running:
        try:
            _poll_cycle(config, reader, poster, sessions, workers, router, jira_client, bot_id, last_channel_ts)
            # Update last_channel_ts from registry/state
        except Exception as e:
            logger.error(f"Poll error: {e}")

        # Wait for next cycle
        for _ in range(int(config.poll_interval * 10)):
            if not running:
                break
            time.sleep(0.1)

    scanner.stop()
    observer.stop()
    observer.join(timeout=5)
    logger.info("Shutdown complete.")


# State for tracking last seen timestamps
_last_channel_ts = "0"


def _poll_cycle(config, reader, poster, sessions, workers, router, jira_client, bot_id, _unused):
    global _last_channel_ts

    # Step 1: Read channel for new messages
    try:
        kwargs = {"channel": config.channel_id, "limit": 20}
        if _last_channel_ts != "0":
            kwargs["oldest"] = _last_channel_ts
        history = reader.conversations_history(**kwargs)
    except Exception as e:
        logger.error(f"Channel read failed: {e}")
        return

    for msg in reversed(history.get("messages", [])):
        ts = msg.get("ts", "")
        if ts <= _last_channel_ts:
            continue

        text = msg.get("text", "")
        # Skip bot messages
        if msg.get("bot_id") or msg.get("subtype"):
            _last_channel_ts = ts
            continue

        # Check for @claude keyword (case-insensitive)
        if not KEYWORD_RE.search(text):
            _last_channel_ts = ts
            continue

        # Skip thread replies (handled separately)
        if msg.get("thread_ts") and msg["thread_ts"] != ts:
            _last_channel_ts = ts
            continue

        # Parse command
        clean_text = KEYWORD_RE.sub("", text).strip()
        cmd = parse(clean_text)

        if cmd.type == "list":
            _handle_list(poster, config.channel_id, ts, workers, sessions)
        elif cmd.type == "task":
            _handle_task(poster, config, ts, cmd, sessions, workers, jira_client)

        _last_channel_ts = ts

    # Update to latest message ts
    if history.get("messages"):
        latest = history["messages"][0]["ts"]  # messages are newest-first
        if latest > _last_channel_ts:
            _last_channel_ts = latest

    # Step 2: Route thread replies for active sessions
    for key, entry in sessions.get_active_sessions().items():
        thread_ts = entry.get("thread_ts")
        last_seen = entry.get("last_thread_ts_seen", "0")
        if not thread_ts:
            continue

        try:
            replies = reader.conversations_replies(
                channel=entry["channel_id"], ts=thread_ts, oldest=last_seen, limit=20
            )
        except Exception as e:
            logger.debug(f"Thread read failed for {key}: {e}")
            continue

        for reply in replies.get("messages", []):
            reply_ts = reply.get("ts", "")
            if reply_ts <= last_seen or reply_ts == thread_ts:
                continue
            # Skip bot messages and own messages
            if reply.get("bot_id") or reply.get("user") == entry.get("_bot_id"):
                sessions.update_field(key, "last_thread_ts_seen", reply_ts)
                continue
            # Skip messages with "Sent using Claude" footer
            if "Sent using" in reply.get("text", ""):
                sessions.update_field(key, "last_thread_ts_seen", reply_ts)
                continue

            text = reply.get("text", "")

            # Check for close/kill
            thread_cmd = parse_thread_command(text)
            if thread_cmd == "close":
                sessions.close_session(key)
                poster.chat_postMessage(
                    channel=entry["channel_id"], thread_ts=thread_ts,
                    text=f"Session `{key}` disconnected. Reconnect: `! slack-connect {entry.get('tmux_session', key)}`"
                )
                sessions.update_field(key, "last_thread_ts_seen", reply_ts)
                break
            elif thread_cmd == "kill":
                result = workers.kill_worker(key)
                poster.chat_postMessage(
                    channel=entry["channel_id"], thread_ts=thread_ts,
                    text=f"Session `{key}` terminated. Cleaned: {', '.join(result['cleaned'])}"
                )
                break

            # Route to worker
            router.route_message(key, entry, text)
            sessions.update_field(key, "last_thread_ts_seen", reply_ts)


def _handle_list(poster, channel, ts, workers, sessions):
    tmux_sessions = workers.list_tmux_sessions()
    active = sessions.get_active_sessions()
    active_tmux = {v.get("tmux_session") for v in active.values()}
    lines = ["*tmux sessions:*"]
    for s in tmux_sessions:
        connected = " (Slack)" if s["name"] in active_tmux else ""
        lines.append(f"  `{s['name']}` — {s['state']}{connected}")
    if not tmux_sessions:
        lines.append("  (none)")
    poster.chat_postMessage(channel=channel, thread_ts=ts, text="\n".join(lines))


def _handle_task(poster, config, ts, cmd, sessions, workers, jira_client):
    session_name = cmd.session_name or cmd.jira_id or generate_session_key(ts)
    description = cmd.description or "No description"
    channel = config.channel_id

    if workers.tmux_session_exists(session_name):
        poster.chat_postMessage(channel=channel, thread_ts=ts, text=f"Connecting to existing session `{session_name}`...")
        workers.connect_existing(session_name, ts, channel)
        return

    poster.chat_postMessage(channel=channel, thread_ts=ts, text=f"Starting `{session_name}`...")
    success = workers.spawn_worker(session_name, cmd.jira_id, description, ts, channel)

    if not success:
        poster.chat_postMessage(channel=channel, thread_ts=ts, text=f"Failed to spawn `{session_name}`.")
        return

    if cmd.jira_id:
        jira_client.transition_to_in_progress(cmd.jira_id)


if __name__ == "__main__":
    main()
