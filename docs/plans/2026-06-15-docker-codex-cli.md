# Docker Codex CLI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a small Docker wrapper for the Codex CLI with runtime support for mounted state, API-key auth, and `OPENAI_BASE_URL`.

**Architecture:** Use an Alpine multi-stage Docker build. The builder runs the Codex standalone installer, and the runtime image copies only the installed package plus a small entrypoint that sets defaults and maps Docker-friendly environment variables to Codex CLI configuration.

**Tech Stack:** Docker, Alpine Linux, POSIX shell, Codex standalone installer.

---

### Task 1: Add Docker Build Inputs

**Files:**
- Create: `install.sh`
- Create: `.dockerignore`
- Create: `Dockerfile`

**Step 1: Copy installer**

Copy the provided Codex standalone installer into `install.sh` unchanged.

**Step 2: Add `.dockerignore`**

Exclude git metadata, local Codex state, dotenv files, logs, and temporary files.

**Step 3: Add `Dockerfile`**

Use Alpine multi-stage build:

- `builder`: install `ca-certificates`, `curl`, `tar`, `gzip`, and run `install.sh` with `CODEX_NON_INTERACTIVE=1`, `CODEX_INSTALL_DIR=/usr/local/bin`, and `CODEX_HOME=/opt/codex`.
- `runtime`: install `ca-certificates`, `git`, and `bash`; copy `/opt/codex` and `/usr/local/bin/codex`; create unprivileged `codex` user; set `WORKDIR /workspace`; install the entrypoint.

**Step 4: Verify syntax surface**

Run: `docker build --help >/dev/null`

Expected: command exits 0, proving Docker CLI is available before build work continues.

### Task 2: Add Runtime Entrypoint

**Files:**
- Create: `docker-entrypoint.sh`
- Modify: `Dockerfile`

**Step 1: Implement entrypoint**

The script must:

- Set `CODEX_HOME` to `/home/codex/.codex` when unset.
- Create `$CODEX_HOME` and `/workspace` if possible.
- Build a config argument list containing `--config openai_base_url='"$OPENAI_BASE_URL"'` when `OPENAI_BASE_URL` is set.
- Try API-key login when `OPENAI_API_KEY` is set and `$CODEX_HOME/auth.json` does not exist.
- Start `codex` when no command is provided.
- Prepend `codex` when the first argument is a Codex flag or known subcommand.
- Execute non-Codex commands unchanged.

**Step 2: Wire Dockerfile**

Copy the entrypoint to `/usr/local/bin/docker-entrypoint.sh`, make it executable, and set it as `ENTRYPOINT` with `CMD ["codex"]`.

**Step 3: Shell syntax check**

Run: `sh -n docker-entrypoint.sh`

Expected: no output and exit 0.

### Task 3: Add Usage Documentation

**Files:**
- Create: `README.md`

**Step 1: Document build**

Include default and pinned release build commands.

**Step 2: Document run modes**

Include examples for:

- Mounted `~/.codex` state.
- `OPENAI_API_KEY` auth.
- `OPENAI_BASE_URL` proxy override.
- Running `codex exec`.
- Opening a shell inside the image.

**Step 3: Document security notes**

State that secrets are runtime-only and that mounted `auth.json` should be treated as a password.

### Task 4: Build and Verify Image

**Files:**
- None expected beyond generated Docker build cache.

**Step 1: Build**

Run: `docker build -t codex-cli:local .`

Expected: image builds successfully.

**Step 2: Version check**

Run: `docker run --rm codex-cli:local --version`

Expected: prints Codex CLI version and exits 0.

**Step 3: Command passthrough check**

Run: `docker run --rm codex-cli:local sh -lc 'id && pwd && test "$CODEX_HOME" = "/home/codex/.codex"'`

Expected: runs as the `codex` user, prints `/workspace`, and exits 0.

**Step 4: Base URL smoke check**

Run: `docker run --rm -e OPENAI_BASE_URL=https://example.test/v1 codex-cli:local --version`

Expected: prints Codex CLI version and exits 0.
