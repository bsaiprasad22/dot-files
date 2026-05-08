"""Slack-ops bot — Socket Mode entry point."""

import signal
import sys

from slack_bolt import App
from slack_bolt.adapter.socket_mode import SocketModeHandler

from .config import Config
from .events import register_handlers
from .file_watcher import start_watcher
from .jira import JiraClient
from .prompt_scanner import PromptScanner
from .routing import MessageRouter
from .sessions import SessionManager
from .utils import logger, setup_logging
from .workers import WorkerManager


def main() -> None:
    setup_logging()
    logger.info("Loading config...")

    config = Config.load()
    errors = config.validate()
    if errors:
        for e in errors:
            logger.error(e)
        sys.exit(1)

    logger.info(f"Channel: {config.channel_id}, State: {config.state_dir}")

    # Initialize components
    app = App(token=config.slack_bot_token)
    sessions = SessionManager(config.state_dir)
    workers = WorkerManager(config, sessions)
    router = MessageRouter(config, sessions)
    jira_client = JiraClient(config)

    # Register Slack event handlers
    register_handlers(app, config, sessions, workers, router, jira_client)

    # Start file watcher (pending-response, pending-prompt, pending-connect)
    observer = start_watcher(config, sessions, app.client)

    # Start prompt scanner (5s interval)
    scanner = PromptScanner(config, sessions, app.client, router, config.prompt_scan_interval)
    scanner.start()

    # Cleanup dead sessions on startup
    dead = sessions.cleanup_dead_sessions()
    if dead:
        logger.info(f"Cleaned stale sessions: {dead}")

    # Trim old closed entries
    trimmed = sessions.trim_old_closed()
    if trimmed:
        logger.info(f"Trimmed {trimmed} old closed entries")

    # Graceful shutdown
    def shutdown(sig, frame):
        logger.info("Shutting down...")
        scanner.stop()
        observer.stop()
        observer.join(timeout=5)
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    # Start Socket Mode (blocks forever)
    logger.info("Starting Socket Mode...")
    handler = SocketModeHandler(app, config.slack_app_token)
    handler.start()


if __name__ == "__main__":
    main()
