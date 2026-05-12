---
name: prod-deploy
description: Deploy penops-core backend changes to the cherry-picker production instance. Use when deploying, restarting, or checking logs on production. Covers Flask (pubsub_vm) and Jenkins workspace (bd) deployments.
argument-hint: "[deploy|logs|restart|status|jenkins-deploy|rollback]"
---

# Production Deployment — Cherry Picker Backend

Deploy, monitor, and manage the cherry-picker backend production instance. **Higher caution than staging** — production serves live cherrypick + prepare_branch traffic.

## Production Hosts

### Flask App (pubsub_vm)
- **Host**: `pubsub_vm` (10.11.0.72), SSH alias works
- **Code path**: `/var/opt/penops-core` (NOT `/ws/vm/penops-core` or `/home/vm/...` — those are dev/dead)
- **Service path**: `services/github_ps_system/subscribers/cherry_picker`
- **Deployment scripts**: `deployment/production/`
- **Containers**: `cp-production-ocp` (port 9091), `cp-production-acp` (port 9090), `cp-production-celery`, `cp-production-redis`
- **Compose file**: `deployment/production/docker-compose.production.yaml`
- **Production URL**: `penops.test.pensando.io`

### Jenkins Workspace (bd VM)
- **Host**: `blackduck@bd` (SSH alias proxied via dev7)
- **Production workspace**: `/home/blackduck/jenkins-projects/branch_creation_tool/`
- **Test workspace**: `/home/blackduck/jenkins-projects/test_jobs/branch_creation_tool_test/`
- **Production Jenkins job**: `branch-creation-tool` (note: dash, not underscore)
- **Test Jenkins job**: `branch_creation_tool_test`

## Pre-Deploy Checklist (READ FIRST)

1. **Diff prod against your branch first** — production may be behind by months and have uncommitted in-flight modifications
   ```bash
   ssh pubsub_vm "cd /var/opt/penops-core && sudo git log --oneline -1 && sudo git status --short | head -20"
   ```
2. **Never `git checkout` blindly** — uncommitted changes on prod (config files, secrets, env, manually-added files like `app_auth.py`) would be destroyed
3. **Disk space check** — production VM tends to fill up; builds fail at 100%
   ```bash
   ssh pubsub_vm "df -h /var | head -2 && sudo docker system df"
   ```
4. **Confirm services were running before** — verify OCP/ACP containers/processes are alive before assuming a deploy is just "restart"

## Commands

### deploy (Flask side)

Surgical file-by-file SCP rather than `git pull` to avoid destroying in-flight work:

1. **Verify only expected files differ** between your branch and production base
   ```bash
   cd /home/vm/worktrees/<JIRA-ID>
   git diff --stat <prod-commit>..HEAD -- services/github_ps_system/subscribers/cherry_picker/prepare_branch/
   ```

2. **Stage files in temp on prod host** (works around sudo + scp permission mix):
   ```bash
   ssh pubsub_vm "mkdir -p /tmp/<JIRA-ID>-deploy/{plugins,utils,tests}"
   scp <files> pubsub_vm:/tmp/<JIRA-ID>-deploy/...
   ```

3. **Move into place with sudo**:
   ```bash
   ssh pubsub_vm "sudo cp /tmp/<JIRA-ID>-deploy/<file> /var/opt/penops-core/.../<dest>/"
   ```

4. **Restart via run_production.sh — NEVER bare `docker compose up`**:
   ```bash
   ssh pubsub_vm "sudo bash /var/opt/penops-core/services/github_ps_system/subscribers/cherry_picker/deployment/production/run_production.sh"
   ```
   The script `source`s the env file before running compose. `docker compose up -d` directly leaves all `${VAR}` substitutions empty and breaks GitHub App auth.

5. **Verify env vars in container**:
   ```bash
   ssh pubsub_vm "sudo docker exec cp-production-ocp env | grep -E 'GITHUB_APP_ID|CLIENT_ID' | sed 's/=.\{8\}.*/=*** (set)/'"
   ```

6. **Smoke test endpoints**:
   ```bash
   ssh pubsub_vm "
   for ep in 'pensando/sw/allowed_metadata' 'pensando/sw/master/bootstrap_config' 'pensando/sw/master/release_owners'; do
     status=\$(curl -s --max-time 10 http://localhost:9091/prepare_branch/\$ep | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"status\",\"?\"))')
     echo \"\$ep: \$status\"
   done
   "
   ```

### jenkins-deploy

Deploy `cli.py` + `repo_handlers/` + updated `utils/` to the production Jenkins workspace:

1. **Always backup first**:
   ```bash
   ssh -o User=blackduck bd "
   TS=\$(date +%Y%m%d-%H%M%S)
   cp -r ~/jenkins-projects/branch_creation_tool ~/jenkins-projects/branch_creation_tool.bak.\$TS
   echo Backup: ~/jenkins-projects/branch_creation_tool.bak.\$TS
   "
   ```

2. **SCP files** (files are picked up on next branch creation request — no restart needed):
   ```bash
   scp -o User=blackduck cli.py blackduck@bd:~/jenkins-projects/branch_creation_tool/
   ssh -o User=blackduck bd "mkdir -p ~/jenkins-projects/branch_creation_tool/repo_handlers/sw"
   scp -o User=blackduck repo_handlers/__init__.py blackduck@bd:~/jenkins-projects/branch_creation_tool/repo_handlers/
   # ... etc
   ```

3. **Sync any utils/ files SwHandler depends on** (production utils may be older):
   ```bash
   # Check md5 mismatches first
   for f in system.py constants.py modify_file.py; do
     local_md5=$(md5sum jenkins/utils/$f | cut -d' ' -f1)
     remote_md5=$(ssh -o User=blackduck bd "md5sum ~/jenkins-projects/branch_creation_tool/utils/$f" | cut -d' ' -f1)
     [ "$local_md5" != "$remote_md5" ] && echo "DIFF: $f"
   done
   ```

### logs

```bash
ssh pubsub_vm "sudo docker logs --tail 50 cp-production-ocp"
ssh pubsub_vm "sudo docker logs --tail 50 cp-production-acp"
# Filter errors:
ssh pubsub_vm "sudo docker logs --since 5m cp-production-ocp 2>&1 | grep -E 'ERROR|Traceback|AttributeError' | tail -10"
```

### restart

```bash
ssh pubsub_vm "
cd /var/opt/penops-core/services/github_ps_system/subscribers/cherry_picker/deployment/production
sudo bash ./stop.sh && sudo bash ./run_production.sh
"
```

### status

```bash
ssh pubsub_vm "
sudo docker ps --format '{{.Names}}\t{{.Status}}' | grep cp-prod
echo '---'
curl -s -o /dev/null -w 'OCP: %{http_code}\n' --max-time 5 http://localhost:9091/health
curl -s -o /dev/null -w 'ACP: %{http_code}\n' --max-time 5 http://localhost:9090/health
"
```

### rollback

**Flask** — restore previous code from git history or your backup:
```bash
# If you saved backups in /tmp/<JIRA-ID>-deploy-backup/, copy them back
ssh pubsub_vm "sudo cp /tmp/<JIRA-ID>-deploy-backup/* /var/opt/penops-core/.../<dest>/"
ssh pubsub_vm "sudo bash /var/opt/penops-core/.../deployment/production/stop.sh && sudo bash /var/opt/penops-core/.../deployment/production/run_production.sh"
```

**Jenkins** — restore from timestamped backup:
```bash
ssh -o User=blackduck bd "
cp -r ~/jenkins-projects/branch_creation_tool.bak.<TIMESTAMP>/. ~/jenkins-projects/branch_creation_tool/
"
# No restart needed — files picked up on next build
```

## Known Gotchas

### Health check is misleading
- `/health` endpoint returns 503 with `"database":"unhealthy"` even when service works fine
- Cause: known issue `module 'db' has no attribute 'db_client'` in health probe
- **Don't gate deploy on /health** — use endpoint smoke tests instead

### Disk space fills up regularly
- `--no-cache` rebuilds pile up images and build cache
- Reclaim with `sudo docker system prune -a -f` (skip `--volumes` unless you've verified no in-use data)
- Verify other running containers survived prune: `sudo docker ps`

### Docker credential helper failures
- Symptom: `failed to solve: python:3.9-slim: error getting credentials - err: exit status 1, out: 'The connection is closed'`
- Workaround: pull base image manually first
  ```bash
  ssh pubsub_vm "sudo docker pull python:3.9-slim"
  ```
- Then retry the build

### `run_production.sh` vs raw `docker compose up`
- The script does `source ./env` to load `GITHUB_APP_ID`, `GITHUB_APP_PEM_PATH`, `SECRET_KEY`, `CLIENT_ID/SECRET`, `NOTIFY_URL`, `ACP_HOST_PORT`, `OCP_HOST_PORT`
- `docker compose up -d` from outside the script gets empty strings for all `${VAR}` substitutions — service starts but auth fails
- **Always use the script.** If debugging compose directly, source env first: `source env && sudo -E docker compose up -d`

### Production code may be behind main by months
- `/var/opt/penops-core` git history may show last commit from months ago
- Don't `git pull` to update — there may be uncommitted in-flight work
- Surgically scp only the files for your change

### Build is required, not just restart
- Dockerfile uses `COPY services/github_ps_system/subscribers/cherry_picker /app/...` — code is baked into the image at build time
- Only `env/` and `logs/` are bind-mounted
- Deploy = update files + `build` + `up`. `restart` alone won't pick up code changes.

### Cached build layers
- Docker reuses unchanged layers. After scp'ing new files, plain `build` may use the cached COPY layer
- Use `build --no-cache` (slow but reliable) or verify with: `docker exec <container> grep <new-symbol> <path>`

### Other services on pubsub_vm
- pubsub_vm runs many other services (jobd-ci-bridge, irm, cns, etc.) — be careful with `docker system prune --volumes`, it removes unused volumes from all projects
- Always verify other containers are still up after cleanup: `sudo docker ps`

## Pre-existing Production Quirks

- `/home/vm/github_ps_system/` exists but is **dead** — old deployment path, systemd services there are inactive/disabled. Don't deploy there.
- `pr-monitor.service` (port 9092) runs from `/home/vm/...` — separate concern, leave alone
- `cp-production-celery` may show "unhealthy" but still functions — health probe issue similar to the Flask one
- `/var/opt/penops-core` may have ~13 uncommitted modifications from past deploy attempts (e.g., manual port of `app_auth.py`). Leave them as-is unless coordinating with the original implementer.

## Notes

- OCP serves `/cherrypick/api/*`, `/prepare_branch/*`, `/prm/*`
- ACP serves webhooks: `/webhook`, `/cp-record`
- Production auth: GitHub App installation tokens (since INFRA-7107) — needs `GITHUB_APP_ID` and `GITHUB_APP_PEM_PATH` env vars + `secrets/penops-internal.pem` file
- Jenkins jobs copy workspace from `~/jenkins-projects/<job>/` at the start of each build → code changes apply to **next** build, not in-flight ones
- Always test in staging first via the `staging-deploy` skill before touching production
