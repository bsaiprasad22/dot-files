"""Configuration loading from .env + config.json."""

import json
import os
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

import requests
from dotenv import load_dotenv

# Slack MCP OAuth token endpoint (public client, PKCE — no client secret).
SLACK_TOKEN_URL = "https://slack.com/api/oauth.v2.user.access"
# agentq plugin's registered OAuth client_id (from its .mcp.json).
DEFAULT_SLACK_CLIENT_ID = "1601185624273.8899143856786"
AGENTQ_MCP_JSON = (
    Path.home()
    / ".claude/plugins/marketplaces/ntsg_claude_plugins/plugins/agentq/.mcp.json"
)


@dataclass
class Config:
    slack_bot_token: str
    slack_user_token: str
    channel_id: str
    jira_url: str
    jira_email: str
    jira_token: str
    default_project_dir: str
    jira_auto_transition: bool
    state_dir: Path
    slack_client_id: str = DEFAULT_SLACK_CLIENT_ID
    oauth_refresh_token: str = ""
    token_expires_at: int = 0  # epoch ms
    keyword: str = "@claude"
    worktree_base: str = "/home/vm/worktrees"
    poll_interval: float = 5.0
    prompt_scan_interval: float = 5.0
    credentials_path: Path = Path.home() / ".claude" / ".credentials.json"

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

        # Load user token from Claude's MCP OAuth credentials
        creds_path = Path.home() / ".claude" / ".credentials.json"
        env_token = env("SLACK_USER_TOKEN")
        entry = cls._load_mcp_slack_entry(creds_path)
        user_token = env_token or entry.get("accessToken", "")

        return cls(
            slack_bot_token=env("SLACK_BOT_TOKEN"),
            slack_user_token=user_token,
            channel_id=file_config.get("channel_id", env("SLACK_CHANNEL_ID", "C0ASZC1A8H4")),
            jira_url=env("JIRA_URL", "https://pensando.atlassian.net"),
            jira_email=env("JIRA_EMAIL"),
            jira_token=env("JIRA_TOKEN"),
            default_project_dir=file_config.get("default_project_dir", "/home/vm/penops-ui"),
            jira_auto_transition=file_config.get("jira_auto_transition", True),
            state_dir=state_dir,
            slack_client_id=env("SLACK_CLIENT_ID") or cls._load_client_id(),
            oauth_refresh_token=entry.get("refreshToken", ""),
            token_expires_at=int(entry.get("expiresAt", 0) or 0),
            keyword=file_config.get("keyword", "@claude"),
            credentials_path=creds_path,
        )

    @staticmethod
    def _load_client_id() -> str:
        """Read the agentq plugin's registered Slack OAuth client_id."""
        try:
            with open(AGENTQ_MCP_JSON) as f:
                mcp = json.load(f)
            cid = mcp.get("slack", {}).get("oauth", {}).get("clientId")
            if cid:
                return cid
        except (json.JSONDecodeError, OSError, AttributeError):
            pass
        return DEFAULT_SLACK_CLIENT_ID

    @staticmethod
    def _slack_key(creds: dict) -> str | None:
        for key in creds.get("mcpOAuth", {}):
            if "slack" in key.lower():
                return key
        return None

    @classmethod
    def _load_mcp_slack_entry(cls, creds_path: Path) -> dict:
        """Return the full Slack MCP OAuth entry (accessToken, refreshToken, expiresAt)."""
        if not creds_path.exists():
            return {}
        try:
            with open(creds_path) as f:
                creds = json.load(f)
            key = cls._slack_key(creds)
            if key:
                return creds["mcpOAuth"][key]
        except (json.JSONDecodeError, OSError):
            pass
        return {}

    def token_expiring_soon(self, within_seconds: int = 300) -> bool:
        """True if the access token is expired or expires within the window."""
        if not self.token_expires_at:
            return False
        return time.time() >= (self.token_expires_at / 1000) - within_seconds

    def refresh_oauth_token(self) -> bool:
        """Perform an OAuth refresh_token grant against Slack and persist the result.

        Public client (PKCE) — client_id only, no secret. Slack rotates the
        refresh token on each success, so persisting the new one is mandatory.
        """
        if not self.oauth_refresh_token or not self.slack_client_id:
            return False
        try:
            resp = requests.post(
                SLACK_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "client_id": self.slack_client_id,
                    "refresh_token": self.oauth_refresh_token,
                },
                headers={"Content-Type": "application/x-www-form-urlencoded"},
                timeout=15,
            ).json()
        except (requests.RequestException, ValueError):
            return False

        if not resp.get("ok") or not resp.get("access_token"):
            return False

        self.slack_user_token = resp["access_token"]
        if resp.get("refresh_token"):
            self.oauth_refresh_token = resp["refresh_token"]
        expires_in = int(resp.get("expires_in", 43200))
        self.token_expires_at = int((time.time() + expires_in) * 1000)

        self._persist_tokens(resp.get("scope"))
        return True

    def _persist_tokens(self, scope: str | None) -> None:
        """Atomically write refreshed tokens back into ~/.claude/.credentials.json."""
        try:
            with open(self.credentials_path) as f:
                creds = json.load(f)
            key = self._slack_key(creds)
            if not key:
                return
            entry = creds["mcpOAuth"][key]
            entry["accessToken"] = self.slack_user_token
            entry["refreshToken"] = self.oauth_refresh_token
            entry["expiresAt"] = self.token_expires_at
            if scope:
                entry["scope"] = scope

            d = os.path.dirname(self.credentials_path)
            fd, tmp = tempfile.mkstemp(dir=d)
            try:
                with os.fdopen(fd, "w") as f:
                    json.dump(creds, f, indent=2)
                os.chmod(tmp, 0o600)
                os.replace(tmp, self.credentials_path)
            except OSError:
                if os.path.exists(tmp):
                    os.unlink(tmp)
                raise
        except (json.JSONDecodeError, OSError):
            pass

    def refresh_user_token(self) -> bool:
        """Re-read user token from credentials file (external refresh fallback)."""
        entry = self._load_mcp_slack_entry(self.credentials_path)
        new_token = entry.get("accessToken", "")
        if new_token and new_token != self.slack_user_token:
            self.slack_user_token = new_token
            self.oauth_refresh_token = entry.get("refreshToken", self.oauth_refresh_token)
            self.token_expires_at = int(entry.get("expiresAt", self.token_expires_at) or 0)
            return True
        return False

    def validate(self) -> list[str]:
        errors = []
        if not self.slack_bot_token:
            errors.append("SLACK_BOT_TOKEN not set")
        if not self.slack_user_token:
            errors.append("SLACK_USER_TOKEN not set (check .env or ~/.claude/.credentials.json)")
        if not self.state_dir.exists():
            errors.append(f"State dir missing: {self.state_dir}")
        return errors
