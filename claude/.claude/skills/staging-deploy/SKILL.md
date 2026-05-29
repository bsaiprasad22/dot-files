---
name: staging-deploy
description: Deploy penops-core backend changes to the cherry-picker staging instance. Use when deploying, restarting, or checking logs on the staging server.
argument-hint: "[deploy|logs|restart|status]"
---

# Staging Deployment — Cherry Picker Backend

Deploy, monitor, and manage the cherry-picker backend staging instance.

## Staging Server

- **Host**: `root@10.30.16.180`
- **Code path**: `~/src/github.com/vijaysg/penops-core`
- **Service path**: `services/github_ps_system/subscribers/cherry_picker`
- **Deployment scripts**: `deployment/staging/`
- **Containers**: `cp-staging-ocp` (API, port 9091), `cp-staging-acp` (webhooks, port 9090), `cp-staging-celery`, `cp-staging-redis`
- **Compose file**: `deployment/staging/docker-compose.staging-integrated.yaml`

## Commands

### deploy (default)

Deploy local changes from the current worktree to staging:

1. Generate patch from local changes:
   ```bash
   git diff <changed-files> > /tmp/staging-deploy.patch
   ```

2. Copy patch to staging:
   ```bash
   scp /tmp/staging-deploy.patch root@10.30.16.180:/tmp/staging-deploy.patch
   ```

3. Apply on staging (revert first to clean state):
   ```bash
   ssh root@10.30.16.180 "cd ~/src/github.com/vijaysg/penops-core && git checkout -- . && git apply /tmp/staging-deploy.patch"
   ```

4. Restart containers:
   ```bash
   ssh root@10.30.16.180 "cd ~/src/github.com/vijaysg/penops-core/services/github_ps_system/subscribers/cherry_picker/deployment/staging && ./stop.sh && ./run_integrated.sh"
   ```

### logs

View OCP (API) container logs:
```bash
ssh root@10.30.16.180 "cd ~/src/github.com/vijaysg/penops-core/services/github_ps_system/subscribers/cherry_picker/deployment/staging && docker compose -f docker-compose.staging-integrated.yaml logs ocp-staging --tail 50"
```

Filter for specific patterns (e.g. filter conditions, errors):
```bash
ssh root@10.30.16.180 "cd ~/src/github.com/vijaysg/penops-core/services/github_ps_system/subscribers/cherry_picker/deployment/staging && docker compose -f docker-compose.staging-integrated.yaml logs ocp-staging 2>/dev/null | grep -E 'Filter condition|Received payload|ERROR' | tail -20"
```

### restart

Restart without redeploying:
```bash
ssh root@10.30.16.180 "cd ~/src/github.com/vijaysg/penops-core/services/github_ps_system/subscribers/cherry_picker/deployment/staging && ./stop.sh && ./run_integrated.sh"
```

### status

Check container status:
```bash
ssh root@10.30.16.180 "cd ~/src/github.com/vijaysg/penops-core/services/github_ps_system/subscribers/cherry_picker/deployment/staging && docker compose -f docker-compose.staging-integrated.yaml ps"
```

## Notes

- Always `git checkout -- .` before applying a new patch to avoid conflicts with previous deployments
- The `run_integrated.sh` script rebuilds Docker images, so code changes are picked up automatically
- OCP serves the `/cherrypick/api/*` endpoints (search, repro_steps, etc.)
- ACP serves webhooks and `/cp-record` endpoints
- Staging URL: `penops-staging.test.pensando.io`
