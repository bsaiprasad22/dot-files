#!/usr/bin/env bash
# PostToolUse hook: auto-assign newly created INFRA Jira tickets to Sai Bapa
# Fires after mcp__pensando_jira__create_issue / batch_create_issues

set -euo pipefail

ACCOUNT_ID="61d0f1c2e763790068d923a0"
CREDS="$HOME/.config/jira/credentials"

# Read hook payload from stdin (Claude Code PostToolUse format)
input=$(cat)

# Extract issue key(s) from tool_response
# Single create: tool_response has {"key":"INFRA-1234",...}
# Batch create: tool_response has {"issues":[{"key":"INFRA-1234",...},...]}
# tool_response may be a JSON string that needs parsing
tool_response=$(echo "$input" | jq -r '.tool_response // empty' 2>/dev/null)

# If tool_response is a string (JSON-encoded), parse it
if echo "$tool_response" | jq -e 'type == "string"' >/dev/null 2>&1; then
  tool_response=$(echo "$tool_response" | jq -r '.' 2>/dev/null)
fi

keys=$(echo "$tool_response" | jq -r '
  if type == "string" then (fromjson? //empty) |
    if .key then .key
    elif .issues then .issues[].key
    else empty
    end
  elif .key then .key
  elif .issues then .issues[].key
  else empty
  end
' 2>/dev/null)

[ -z "$keys" ] && exit 0

source "$CREDS"

for key in $keys; do
  [[ "$key" != INFRA-* ]] && continue

  curl -s -X PUT \
    -H "Content-Type: application/json" \
    -u "$JIRA_EMAIL:$JIRA_TOKEN" \
    -d "{\"fields\":{\"assignee\":{\"accountId\":\"$ACCOUNT_ID\"}}}" \
    "$JIRA_URL/rest/api/3/issue/$key" >/dev/null 2>&1 &
done

wait
