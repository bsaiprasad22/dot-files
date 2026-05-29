---
name: staging-deploy-ui
description: Deploy penops-ui frontend to the cherry-picker staging instance. Build, copy, and verify.
argument-hint: "[deploy|status]"
---

# Staging Deployment — PenOps UI Frontend

Deploy the penops-ui React frontend to the staging server.

## Staging Server

- **Host**: `root@10.30.16.180`
- **Web root**: `/var/www/html`
- **URL**: `https://penops-staging.test.pensando.io`

## Commands

### deploy (default)

Build and deploy from the current penops-ui worktree:

1. Build production bundle:
   ```bash
   npm run build
   ```

2. Copy to staging:
   ```bash
   scp -r build/* root@10.30.16.180:/var/www/html/
   ```

3. Verify deployment:
   ```bash
   ssh root@10.30.16.180 "ls -la /var/www/html/index.html"
   ```

### status

Check what's currently deployed:
```bash
ssh root@10.30.16.180 "ls -la /var/www/html/index.html && cat /var/www/html/asset-manifest.json | head -5"
```

## Notes

- Must be run from a penops-ui worktree or repo directory
- Uses `npm run build` which sets `NODE_ENV=production`
- Build output goes to `build/` directory locally
- The staging server serves static files from `/var/www/html`
