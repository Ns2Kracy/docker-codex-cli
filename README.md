# Docker Codex CLI

Small Docker wrapper for the OpenAI Codex CLI.

The image downloads OpenAI's official standalone installer at build time, installs the Codex CLI, then runs it as an unprivileged `codex` user from `/workspace`. Credentials and Codex state are runtime concerns: mount them or pass environment variables when you start the container.

## Build

The default Codex CLI release is defined in `codex-release.env`:

```env
CODEX_RELEASE=...
```

Change that one file to update the default release used by Docker builds, Docker Compose, and the publish workflow.

```bash
docker build -t codex-cli:local .
```

Override the release for a one-off build when needed:

```bash
docker build \
  --build-arg CODEX_RELEASE=1.2.3 \
  -t codex-cli:1.2.3 .
```

Use `latest` when you want the installer to resolve the newest OpenAI release during the build:

```bash
docker build \
  --build-arg CODEX_RELEASE=latest \
  -t codex-cli:latest .
```

Docker may reuse the cached installer layer on repeated builds. Force a fresh download from OpenAI when you want the latest installer and release resolution. This also means the build will depend on GitHub release API availability because OpenAI's installer verifies release assets there:

```bash
docker build --pull --no-cache -t codex-cli:local .
```

## Run With Local Codex State

Use this when you already have `~/.codex` on the host and want to reuse login state, config, sessions, skills, and other Codex files.

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.codex:/home/codex/.codex" \
  codex-cli:local
```

## Docker Compose

Build the image through Compose:

```bash
docker compose build
```

Start an interactive Codex session:

```bash
docker compose run --rm codex
```

Start a shell when you want to change directories before launching Codex:

```bash
docker compose run --rm shell
```

Then run Codex from the directory you want:

```bash
cd path/inside/workspace
codex
```

Run a one-off Codex command:

```bash
docker compose run --rm codex --version
```

The Compose service mounts the current directory to `/workspace` and `${HOME}/.codex` to `/home/codex/.codex` by default. Override paths or the release for a one-off run with environment variables:

```bash
WORKSPACE=/path/to/project \
CODEX_HOME_HOST="$HOME/.codex" \
CODEX_RELEASE=latest \
docker compose run --rm codex
```

## Publish Images

The GitHub Actions workflow at `.github/workflows/publish-images.yml` publishes the image to both GHCR and Docker Hub on pushes to `main`, tags matching `v*`, or manual dispatch.

Published image names:

- `ghcr.io/<github-owner>/<github-repo>`
- Docker Hub image from repository variable `DOCKERHUB_IMAGE`, or `<github-owner>/<github-repo>` when that variable is unset

Required repository secrets:

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`

Optional repository variable:

- `DOCKERHUB_IMAGE`, for example `ns2kracy/docker-codex-cli`

The workflow publishes multi-architecture images for `linux/amd64` and `linux/arm64`. It reads the default Codex release from `codex-release.env`. For a manual run, set the `codex_release` input to another version or `latest`.

## Run With API Key

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  codex-cli:local
```

When `OPENAI_API_KEY` is set and `/home/codex/.codex/auth.json` does not exist, the container's `codex` command tries `codex login --with-api-key` once before starting Codex. It also exposes the same value as `CODEX_API_KEY` for non-interactive `codex exec` runs. Disable the automatic login attempt with:

```bash
-e CODEX_AUTO_LOGIN=0
```

## Use A Custom OpenAI Base URL

Codex uses `openai_base_url` in its config for the built-in OpenAI provider. This wrapper accepts `OPENAI_BASE_URL` and passes it as a per-run Codex config override.

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  -e OPENAI_BASE_URL="https://your-compatible-endpoint/v1" \
  codex-cli:local
```

This does not rewrite your mounted `config.toml`. The container's `codex` command applies the override both when Codex starts directly and when you start a shell first, change directories, then run `codex` manually.

## Non-Interactive Example

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  codex-cli:local \
  exec --sandbox workspace-write "summarize this repository"
```

## Shell Access

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  codex-cli:local bash
```

Inside the shell, `cd` to any directory under `/workspace`, then run `codex`.

Check the runtime environment from inside Compose:

```bash
docker compose run --rm codex sh -lc 'printf "OPENAI_BASE_URL=%s\nCODEX_HOME=%s\n" "$OPENAI_BASE_URL" "$CODEX_HOME"'
docker compose run --rm shell bash -lc 'printf "OPENAI_BASE_URL=%s\n" "$OPENAI_BASE_URL"'
```

## Adding Project Tooling

The runtime image intentionally stays small. It includes only Alpine base utilities, certificates, `git`, `bash`, and the Codex standalone package. For project-specific tools, derive your own image:

```Dockerfile
FROM codex-cli:local

USER root
RUN apk add --no-cache nodejs npm python3 py3-pip
USER codex
```

## Security Notes

- The image does not contain credentials by default.
- Treat mounted `~/.codex/auth.json` like a password because it can contain access tokens.
- Prefer runtime environment variables or Docker secrets over baking API keys into images.
- Be careful passing API keys to containers running untrusted repository code.
