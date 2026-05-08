"""Slack event handlers — app_mention + message routing."""

import re

from slack_bolt import App

from .commands import parse, parse_thread_command
from .config import Config
from .jira import JiraClient
from .routing import MessageRouter
from .sessions import SessionManager
from .utils import generate_session_key, logger, strip_mention, truncate
from .workers import WorkerManager

KEYWORD_RE = re.compile(r"@claude\b", re.IGNORECASE)


def register_handlers(
    app: App,
    config: Config,
    sessions: SessionManager,
    workers: WorkerManager,
    router: MessageRouter,
    jira: JiraClient,
) -> None:

    @app.event("app_mention")
    def handle_mention(event, say, client):
        channel = event["channel"]
        if channel != config.channel_id:
            return

        text = strip_mention(event["text"])
        ts = event["ts"]
        thread_ts = event.get("thread_ts")

        # Thread reply with @mention — treat as thread command
        if thread_ts:
            _handle_thread_reply(text, thread_ts, channel, sessions, workers, router, say)
            return

        # Top-level mention
        cmd = parse(text)

        if cmd.type == "list":
            _handle_list(workers, sessions, say, ts)
        elif cmd.type == "task":
            _handle_new_task(cmd, ts, channel, config, sessions, workers, jira, say)

    @app.event("message")
    def handle_message(event, client):
        # Skip bot messages, edits, subtypes
        if event.get("bot_id") or event.get("subtype"):
            return

        channel = event.get("channel")
        if channel != config.channel_id:
            return

        thread_ts = event.get("thread_ts")
        text = event.get("text", "")

        # Top-level message with @claude keyword (backward compat with /slack-task)
        if not thread_ts and KEYWORD_RE.search(text):
            text = KEYWORD_RE.sub("", text).strip()
            cmd = parse(text)
            ts = event["ts"]

            if cmd.type == "list":
                client.chat_postMessage(channel=channel, thread_ts=ts, text=_format_list(workers, sessions))
            elif cmd.type == "task":
                _handle_new_task(cmd, ts, channel, config, sessions, workers, jira,
                                lambda **kw: client.chat_postMessage(channel=channel, **kw))
            return

        # Thread reply to tracked session
        if thread_ts:
            result = sessions.find_by_thread(thread_ts)
            if not result:
                return
            key, entry = result
            if entry["status"] != "active":
                return

            # Check for close/kill commands
            thread_cmd = parse_thread_command(text)
            if thread_cmd == "close":
                sessions.close_session(key)
                client.chat_postMessage(
                    channel=channel, thread_ts=thread_ts,
                    text=f"Session `{key}` disconnected. Terminal still running. Reconnect with `! slack-connect {entry.get('tmux_session', key)}`."
                )
                return
            elif thread_cmd == "kill":
                result = workers.kill_worker(key)
                client.chat_postMessage(
                    channel=channel, thread_ts=thread_ts,
                    text=f"Session `{key}` terminated. Cleaned: {', '.join(result['cleaned'])}."
                )
                return

            # Route to worker
            router.route_message(key, entry, text)
            sessions.update_field(key, "last_thread_ts_seen", event["ts"])


def _handle_thread_reply(text, thread_ts, channel, sessions, workers, router, say):
    result = sessions.find_by_thread(thread_ts)
    if not result:
        return
    key, entry = result
    thread_cmd = parse_thread_command(text)
    if thread_cmd == "close":
        sessions.close_session(key)
        say(thread_ts=thread_ts, text=f"Session `{key}` disconnected.")
    elif thread_cmd == "kill":
        cleaned = workers.kill_worker(key)
        say(thread_ts=thread_ts, text=f"Session `{key}` terminated. Cleaned: {', '.join(cleaned['cleaned'])}.")
    else:
        router.route_message(key, entry, text)


def _handle_list(workers, sessions, say, ts):
    say(thread_ts=ts, text=_format_list(workers, sessions))


def _format_list(workers, sessions) -> str:
    tmux_sessions = workers.list_tmux_sessions()
    active = sessions.get_active_sessions()
    active_tmux = {v.get("tmux_session") for v in active.values()}

    lines = ["*tmux sessions:*"]
    for s in tmux_sessions:
        connected = " (Slack)" if s["name"] in active_tmux else ""
        lines.append(f"  `{s['name']}` — {s['state']}{connected}")
    if not tmux_sessions:
        lines.append("  (none)")
    return "\n".join(lines)


def _handle_new_task(cmd, ts, channel, config, sessions, workers, jira, say):
    session_name = cmd.session_name or cmd.jira_id or generate_session_key(ts)
    description = cmd.description or "No description"

    # Check if session already exists in tmux — connect instead
    if workers.tmux_session_exists(session_name):
        say(thread_ts=ts, text=f"Connecting to existing session `{session_name}`...")
        workers.connect_existing(session_name, ts, channel)
        return

    say(thread_ts=ts, text=f"Starting `{session_name}`...")
    success = workers.spawn_worker(session_name, cmd.jira_id, description, ts, channel)

    if not success:
        say(thread_ts=ts, text=f"Failed to spawn session `{session_name}`.")
        return

    # Jira transition
    if cmd.jira_id:
        jira.transition_to_in_progress(cmd.jira_id)
