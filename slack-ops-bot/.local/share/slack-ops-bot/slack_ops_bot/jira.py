"""Jira REST API — transitions only."""

import requests

from .config import Config
from .utils import logger


class JiraClient:
    def __init__(self, config: Config):
        self.base_url = config.jira_url.rstrip("/")
        self.auth = (config.jira_email, config.jira_token)
        self.enabled = config.jira_auto_transition

    def transition_to_in_progress(self, issue_key: str) -> bool:
        if not self.enabled:
            return False
        try:
            transitions = self.get_transitions(issue_key)
            target = next(
                (t for t in transitions if "progress" in t["name"].lower()),
                None,
            )
            if not target:
                logger.warning(f"No 'In Progress' transition for {issue_key}")
                return False

            resp = requests.post(
                f"{self.base_url}/rest/api/3/issue/{issue_key}/transitions",
                json={"transition": {"id": target["id"]}},
                auth=self.auth,
                timeout=10,
            )
            resp.raise_for_status()
            logger.info(f"Transitioned {issue_key} to In Progress")
            return True
        except Exception as e:
            logger.warning(f"Jira transition failed for {issue_key}: {e}")
            return False

    def get_transitions(self, issue_key: str) -> list[dict]:
        try:
            resp = requests.get(
                f"{self.base_url}/rest/api/3/issue/{issue_key}/transitions",
                auth=self.auth,
                timeout=10,
            )
            resp.raise_for_status()
            return resp.json().get("transitions", [])
        except Exception as e:
            logger.warning(f"Failed to get transitions for {issue_key}: {e}")
            return []

    def issue_exists(self, issue_key: str) -> bool:
        try:
            resp = requests.head(
                f"{self.base_url}/rest/api/3/issue/{issue_key}",
                auth=self.auth,
                timeout=10,
            )
            return resp.status_code == 200
        except Exception:
            return False
