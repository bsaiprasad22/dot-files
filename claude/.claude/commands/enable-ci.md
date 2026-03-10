# Enable JobD CI for a Pensando GitHub Repository

You are enabling JobD CI for a Pensando GitHub repository. Follow the steps below exactly. The template repo is `pensando/jobd-ci-enablement` (branch `ci-enablement`). Reference: https://amd.atlassian.net/wiki/spaces/EN/pages/1348537882

## Phase 0: Setup

1. **Get inputs from the user.** Ask for (skip any already provided as arguments):
   - GitHub repo name (e.g., `pensando/k8s-device-plugin`)
   - Jira ticket ID — if none, create one in INFRA project with summary "Enable JobD CI for <repo-name>"
   - Whether IRM/custom versioning is needed (default: no, standard JOBD versioning)

2. **Clone and set up worktree:**
   ```bash
   cd /home/vm
   git clone git@github.com:<repo-name>.git
   ```
   Detect the default branch (`main` or `master`):
   ```bash
   cd /home/vm/<repo-name> && git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
   ```
   Create worktree:
   ```bash
   git worktree add /home/vm/worktrees/<JIRA-ID> -b <JIRA-ID> <default-branch>
   ```

3. **Clone the template repo** for reference:
   ```bash
   git clone git@github.com:pensando/jobd-ci-enablement.git /home/vm/jobd-ci-enablement -b ci-enablement
   ```
   If already cloned, skip this step.

4. **Move Jira ticket to In Progress.**

## Phase 1: Stage 1 — Base Image & CI Bootstrap

### Understand the repo
- Check if a `Dockerfile` already exists at the repo root
- Identify the base image and language/runtime (Go, Python, C, etc.)
- Check existing `.github/`, `.gitignore`, any existing CI files

### Create CI directory files

1. **`CI/Makefile`** — Copy from template (`/home/vm/jobd-ci-enablement/CI/Makefile`). The ONLY change allowed is:
   ```
   NAME := <repo-name>
   ```
   Do NOT modify anything else in this file.

2. **`CI/build_base_image.sh`** — Copy from template as-is. No modifications needed. Make executable.

### Create root-level CI config files

3. **`box.rb`** — Copy from template (`/home/vm/jobd-ci-enablement/box.rb`). Update TWO values:
   ```ruby
   from "<base-image-reference>"
   # For fresh targets: "registry.test.pensando.io:5000/pensando/<repo-name>:v1"

   work_dir = "/<repo-name>"
   ```
   The rest of box.rb stays identical to template (user management, timezone, entrypoint).

4. **`entrypoint.sh`** — Copy from template (`/home/vm/jobd-ci-enablement/entrypoint.sh`). Update ONE value:
   ```bash
   dir=/<repo-name>
   ```
   Make executable.

### Prepare the Dockerfile

The existing Dockerfile may need additional packages for `box.rb` compatibility. `box.rb` runs commands like `groupadd`, `useradd`, `userdel`, `groupdel`, `localedef`, `ln -s` (timezone), `git config`, `chown`, `runuser` inside the image.

**Required packages by base OS:**

For **Alpine**-based images, add to the final/runtime stage:
```
bash sudo shadow tzdata git make util-linux
```

For **Ubuntu/Debian**-based images, these are typically already available or add:
```
bash sudo tzdata git make
```

**Important considerations:**
- If the Dockerfile is multi-stage, add packages to the FINAL stage (the one that produces the runtime image), since that's what `box.rb` layers on top of
- If the Dockerfile uses Ubuntu, `localedef` works natively. If Alpine, the `localedef` call in box.rb may need `2>/dev/null || true` (but the template already handles this for root user only)
- Do NOT add language toolchains (Go, Python, etc.) or build dependencies to the Dockerfile for CI purposes — that's the developers' responsibility

**Ask the user** before modifying the Dockerfile. Show them what packages need to be added and why.

### Validate Stage 1

Build the base image locally (no push to registry yet):
```bash
cd /home/vm/worktrees/<JIRA-ID>
docker build -t registry.test.pensando.io:5000/pensando/<repo-name>:v1 -f Dockerfile .
```

Test `box.rb` and dev container launch:
```bash
cd /home/vm/worktrees/<JIRA-ID>/CI
DOCKER_API_VERSION=1.24 make docker/build
```

**NOTE:** `DOCKER_API_VERSION=1.24` is required because `box` v0.5.7 uses an older Docker API. Check with `box --version` — if the version is updated this may no longer be needed.

If `docker/build` succeeds, test container start:
```bash
DOCKER_API_VERSION=1.24 make docker/start
```

Verify the container is running:
```bash
docker ps --filter name=<user>_<first-9-chars-of-name>
```

If the container exits immediately, check logs:
```bash
docker logs <container-name>
```

**Common failures and fixes:**
| Error | Cause | Fix |
|-------|-------|-----|
| `groupadd: not found` | Missing `shadow` package | Add `shadow` to Dockerfile |
| `runuser: not found` | Missing `util-linux` package | Add `util-linux` to Dockerfile |
| `git: not found` | Missing `git` package | Add `git` to Dockerfile |
| `localedef: not found` | Alpine doesn't have glibc locales | Add `|| true` or skip — only affects root/JOBD context |
| `client version 1.23 is too old` | box uses old Docker API | Export `DOCKER_API_VERSION=1.24` |

After successful validation, **clean up** test containers:
```bash
docker stop <container-name> && docker rm <container-name>
rm -f /home/vm/worktrees/<JIRA-ID>/CI/.container_name
```

**Commit Stage 1 changes.**

## Phase 2: Stage 2 — App Build Targets

This stage is the **developers' responsibility**. They need to:
- Create or update a root-level Makefile with app-specific build/test/package targets
- Validate those targets run inside the dev container from Stage 1

**Skip this stage** — inform the user that devs need to add their app build targets and test them inside the container via `make docker/shell`.

## Phase 3: Stage 3 — `.job.yml`

Create `.job.yml` at the repo root. Copy structure from template (`/home/vm/jobd-ci-enablement/.job.yml`).

Create a **placeholder** `.job.yml` since actual build commands depend on Stage 2 (dev's Makefile):

```yaml
# Copyright(C) 2025 Advanced Micro Devices, Inc. All rights reserved.

---
version: 2.0
image:
  bind_dir: "/<repo-name>"

targets:
# Update commands and artifacts once app Makefile is ready
  build-<repo-name>-pkg:
    commands: [
      "sh",
      "-c",
      "cd /<repo-name> && echo '[PLACEHOLDER] update with actual build commands'"
    ]
    owners: ["email:teja.mudragada@amd.com"]
    artifacts:
      - /<repo-name>/build_artifacts.tar.gz
```

**Note to user:** Once Stage 2 (app Makefile) is complete, update:
- `commands` to call actual make targets
- `artifacts` to list actual build outputs
- Add `build-dependencies` if using IRM versioning
- Add VM/BM resource sections if needed (see template for examples)

**Commit Stage 3 changes.**

## Phase 4: Stage 4 — Asset Push

Copy the `tools/asset-push/` directory from template:
```bash
mkdir -p /home/vm/worktrees/<JIRA-ID>/tools/asset-push
cp /home/vm/jobd-ci-enablement/tools/asset-push/* /home/vm/worktrees/<JIRA-ID>/tools/asset-push/
```

Update these files:

1. **`tools/asset-push/artifacts.txt`** — Replace artifact paths with actual ones for this repo:
   ```
   /<repo-name>/out/artifact1.tar.gz
   /<repo-name>/out/artifact2.tar.gz
   ```
   Ask the user what artifacts the build produces, or leave as placeholder.

2. **`tools/asset-push/push.sh`** — Update TWO values:
   ```bash
   ASSET_NAME="<repo-name>"
   ASSET_DIR_DEPTH=platform/drivers/asset-built  # update if needed
   ```

3. **`tools/asset-push/.job.yml`** — Update paths and build dependency:
   ```yaml
   ---
   version: 2.0
   targets:
     push-artifacts:
       commands: [ "sh", "-c", "cd /<repo-name> && tools/asset-push/push.sh --artifact-file tools/asset-push/artifacts.txt" ]
       owners: [ "email:teja.mudragada@amd.com" ]
       build-dependencies:
       - build-<repo-name>-pkg
   image:
     bind_dir: "/<repo-name>"
     work_dir: "/<repo-name>"
   ```

**Commit Stage 4 changes.**

## Phase 5: Stage 5 — CODEOWNERS & Webhook

1. **Create `.github/CODEOWNERS`** (if `.github/` dir exists, add to it; otherwise create it):
   ```
   box.rb @tmudraga @akashp-git
   .job.yml @tmudraga @akashp-git
   Dockerfile @tmudraga @akashp-git
   /CI @tmudraga @akashp-git
   /tools/asset-push @tmudraga @akashp-git
   ```
   If a CODEOWNERS file already exists, append these entries.

2. **Commit all remaining changes and push the branch.**

3. **Webhook activation** — Inform the user to request webhook enablement:
   - Slack: `#test-infra`
   - Mention: `@vgopinat @tmudraga @apavaska`
   - Message: "Please enable the CI webhook for `pensando/<repo-name>` repository"

## Phase 6: Jira Wrap-up

Post a summary comment to the Jira ticket via MCP (`mcp__pensando_jira__add_comment`) with:
- Files added/modified
- Which stages are complete vs pending dev action
- Next steps (devs: Stage 2 app Makefile, update .job.yml commands, webhook request)

## Key Principles

- **Follow the template exactly** — only change values explicitly called out (NAME, repo paths, image references)
- **Do NOT modify `CI/Makefile`** beyond the `NAME` field
- **Do NOT modify `CI/build_base_image.sh`** — copy as-is from template
- **Do NOT create app build targets** — that's the developers' responsibility
- **Dockerfile changes are minimal** — only add packages required for `box.rb` compatibility
- **Always validate** Stage 1 before proceeding (docker build + make docker/build + make docker/start)
- **Commit after each stage** with `<JIRA-ID>:` prefix
- **No AI watermarks** in commit messages
- **Always push to private remote** (`bsaiprasad22/<repo-name>`), never to origin. If the `private` remote doesn't exist, create it:
  ```bash
  git remote add private git@github.com:bsaiprasad22/<repo-name>.git
  ```
  Push with: `git push -u private <JIRA-ID>`
  Create PRs from the private fork against upstream origin.
