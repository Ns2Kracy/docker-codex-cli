# Docker Codex CLI

Small Docker wrapper for the OpenAI Codex CLI.

The image installs the standalone Codex CLI at build time, then runs it as an unprivileged `codex` user from `/workspace`. Credentials and Codex state are runtime concerns: mount them or pass environment variables when you start the container.

## Build

```bash
docker build -t codex-cli:local .
```

Pin a specific Codex release when needed:

```bash
docker build \
  --build-arg CODEX_RELEASE=1.2.3 \
  -t codex-cli:1.2.3 .
```

`CODEX_RELEASE=latest` is the default.

## Run With Local Codex State

Use this when you already have `~/.codex` on the host and want to reuse login state, config, sessions, skills, and other Codex files.

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  -v "$HOME/.codex:/home/codex/.codex" \
  codex-cli:local
```

## Run With API Key

```bash
docker run -it --rm \
  -v "$PWD:/workspace" \
  -e OPENAI_API_KEY="$OPENAI_API_KEY" \
  codex-cli:local
```

When `OPENAI_API_KEY` is set and `/home/codex/.codex/auth.json` does not exist, the entrypoint tries `codex login --with-api-key` once before starting Codex. It also exposes the same value as `CODEX_API_KEY` for non-interactive `codex exec` runs. Disable the automatic login attempt with:

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

This does not rewrite your mounted `config.toml`.

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
