"""Configuration loading from .env + config.json."""

import json
import os
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv


@dataclass
class Config:
    slack_bot_token: str
    slack_app_token: str
    channel_id: str
    jira_url: str
    jira_email: str
    jira_token: str
    default_project_dir: str
    jira_auto_transition: bool
    state_dir: Path
    keyword: str = "@claude"
    worktree_base: str = "/home/vm/worktrees"
    prompt_scan_interval: float = 5.0

    @classmethod
    def load(cls, env_path: str | None = None) -> "Config":
        state_dir = Path.home() / ".local" / "share" / "slack-ops"
        bot_dir = Path.home() / ".local" / "share" / "slack-ops-bot"

        # Load .env (bot dir first, then state dir)
        if env_path:
            load_dotenv(env_path)
        else:
            load_dotenv(bot_dir / ".env")

        # Load config.json from state dir
        config_path = state_dir / "config.json"
        file_config = {}
        if config_path.exists():
            with open(config_path) as f:
                file_config = json.load(f)

        def env(key: str, default: str = "") -> str:
            return os.environ.get(key, default)

        return cls(
            slack_bot_token=env("SLACK_BOT_TOKEN"),
            slack_app_token=env("SLACK_APP_TOKEN"),
            channel_id=file_config.get("channel_id", env("SLACK_CHANNEL_ID", "C0ASZC1A8H4")),
            jira_url=env("JIRA_URL", "https://pensando.atlassian.net"),
            jira_email=env("JIRA_EMAIL"),
            jira_token=env("JIRA_TOKEN"),
            default_project_dir=file_config.get("default_project_dir", "/home/vm/penops-ui"),
            jira_auto_transition=file_config.get("jira_auto_transition", True),
            state_dir=state_dir,
            keyword=file_config.get("keyword", "@claude"),
        )

    def validate(self) -> list[str]:
        errors = []
        if not self.slack_bot_token:
            errors.append("SLACK_BOT_TOKEN not set")
        if not self.slack_app_token:
            errors.append("SLACK_APP_TOKEN not set")
        if not self.state_dir.exists():
            errors.append(f"State dir missing: {self.state_dir}")
        return errors
