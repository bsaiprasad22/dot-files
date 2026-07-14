"""Tests for durable OAuth refresh in Config."""

import json
import time
from pathlib import Path

import pytest

from slack_ops_bot.config import Config


def _write_creds(path: Path, access="xoxe.xoxp-OLD", refresh="xoxe-OLD", expires_at=0):
    creds = {
        "mcpOAuth": {
            "plugin:agentq:slack|deadbeef": {
                "serverName": "plugin:agentq:slack",
                "serverUrl": "https://mcp.slack.com/mcp",
                "accessToken": access,
                "refreshToken": refresh,
                "expiresAt": expires_at,
                "scope": "identify,chat:write",
            }
        }
    }
    path.write_text(json.dumps(creds, indent=2))


def _make_config(creds_path: Path) -> Config:
    return Config(
        slack_bot_token="xoxb-test",
        slack_user_token="xoxe.xoxp-OLD",
        channel_id="C123",
        jira_url="https://x",
        jira_email="a@b.c",
        jira_token="t",
        default_project_dir="/tmp",
        jira_auto_transition=False,
        state_dir=Path("/tmp"),
        slack_client_id="1601185624273.8899143856786",
        oauth_refresh_token="xoxe-OLD",
        token_expires_at=0,
        credentials_path=creds_path,
    )


def test_refresh_success_updates_and_persists(tmp_path, monkeypatch):
    creds = tmp_path / ".credentials.json"
    _write_creds(creds)
    cfg = _make_config(creds)

    def fake_post(url, data, headers, timeout):
        assert data["grant_type"] == "refresh_token"
        assert data["client_id"] == "1601185624273.8899143856786"
        assert data["refresh_token"] == "xoxe-OLD"

        class R:
            def json(self):
                return {
                    "ok": True,
                    "token_type": "Bearer",
                    "access_token": "xoxe.xoxp-NEW",
                    "refresh_token": "xoxe-NEW",
                    "expires_in": 43200,
                    "scope": "identify,chat:write",
                }

        return R()

    monkeypatch.setattr("slack_ops_bot.config.requests.post", fake_post)

    before = time.time()
    assert cfg.refresh_oauth_token() is True
    assert cfg.slack_user_token == "xoxe.xoxp-NEW"
    assert cfg.oauth_refresh_token == "xoxe-NEW"
    assert cfg.token_expires_at >= int((before + 43200) * 1000)

    # persisted to disk
    saved = json.loads(creds.read_text())
    entry = saved["mcpOAuth"]["plugin:agentq:slack|deadbeef"]
    assert entry["accessToken"] == "xoxe.xoxp-NEW"
    assert entry["refreshToken"] == "xoxe-NEW"
    # file mode preserved at 0600
    assert (creds.stat().st_mode & 0o777) == 0o600


def test_refresh_failure_returns_false_and_no_write(tmp_path, monkeypatch):
    creds = tmp_path / ".credentials.json"
    _write_creds(creds)
    cfg = _make_config(creds)
    original = creds.read_text()

    def fake_post(url, data, headers, timeout):
        class R:
            def json(self):
                return {"ok": False, "error": "invalid_grant"}

        return R()

    monkeypatch.setattr("slack_ops_bot.config.requests.post", fake_post)

    assert cfg.refresh_oauth_token() is False
    assert cfg.slack_user_token == "xoxe.xoxp-OLD"
    assert creds.read_text() == original  # untouched on failure


def test_token_expiring_soon(tmp_path):
    creds = tmp_path / ".credentials.json"
    _write_creds(creds)
    cfg = _make_config(creds)
    cfg.token_expires_at = int((time.time() + 30) * 1000)
    assert cfg.token_expiring_soon(within_seconds=120) is True
    cfg.token_expires_at = int((time.time() + 3600) * 1000)
    assert cfg.token_expiring_soon(within_seconds=120) is False
