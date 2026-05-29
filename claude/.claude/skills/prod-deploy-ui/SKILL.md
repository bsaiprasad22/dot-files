---
name: prod-deploy-ui
description: Deploy penops-ui frontend to production. Backs up current deployment, copies new build, restarts nginx. Only deploys from main branch.
argument-hint: "[deploy|status|rollback]"
---

# Production Deployment — PenOps UI Frontend

Deploy the penops-ui React frontend to the production server. **Only deploys from main branch.**

## Production Server

- **Host**: `vm@10.11.0.72`
- **Web root**: `/var/www/html`
- **App directory**: `/home/vm/apps/cherry-pick-tool/`
- **Backup directory**: `/home/vm/apps/`
- **Backup script**: `/home/vm/apps/backup.sh`
- **URL**: `https://penops.test.pensando.io`

## Commands

### deploy (default)

**Pre-flight check**: Verify you're on the main branch or deploying from main:

```bash
git rev-parse --abbrev-ref HEAD  # Must be main, or build from main
```

1. Build production bundle locally:
   ```bash
   cd /home/vm/penops-ui && npm run build
   ```

2. Create backup on production server:
   ```bash
   ssh vm@10.11.0.72 "cd /home/vm/apps && bash backup.sh"
   ```

3. Copy build to app directory:
   ```bash
   scp -r build/* vm@10.11.0.72:/home/vm/apps/cherry-pick-tool/
   ```

4. Replace web root with new build:
   ```bash
   ssh vm@10.11.0.72 "sudo rm -rf /var/www/html/* && sudo cp -r /home/vm/apps/cherry-pick-tool/* /var/www/html/"
   ```

5. Restart nginx and verify:
   ```bash
   ssh vm@10.11.0.72 "sudo systemctl restart nginx && sudo systemctl status nginx"
   ```

### status

Check current deployment and nginx status:
```bash
ssh vm@10.11.0.72 "ls -la /var/www/html/index.html && sudo systemctl status nginx --no-pager -l"
```

### rollback

Restore from the most recent backup:
```bash
ssh vm@10.11.0.72 "ls -lt /home/vm/apps/backups/ | head -5"
```
Then restore the backup (ask user which backup to restore).

## Safety

- **Always backup before deploying** — the backup.sh script handles this
- **Only deploy from main** — never deploy feature branches to production
- **Verify nginx status** after restart
- **Ask user for confirmation** before executing — this is a production deployment
