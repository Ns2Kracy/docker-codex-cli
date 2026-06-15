# Docker Codex CLI Design

## Goal

Package the Codex CLI as a small Docker image that can run interactively against a mounted workspace.

## Confirmed Requirements

- Keep the image as small as practical.
- Support persisted Codex state by mounting a host `~/.codex` directory into the container.
- Support runtime API-key usage through `OPENAI_API_KEY`.
- Support a user-facing `OPENAI_BASE_URL` environment variable for OpenAI-compatible proxies or custom endpoints.
- Do not bake credentials or local Codex state into the image.

## Source Notes

The current Codex manual documents `CODEX_HOME` as the root for CLI state, including config, auth, logs, sessions, skills, and standalone package metadata. It also documents `openai_base_url` as the configuration key for changing the built-in OpenAI provider base URL. The stable environment variable list does not document `OPENAI_BASE_URL` as a direct Codex CLI variable, so the Docker entrypoint will translate `OPENAI_BASE_URL` into a `--config openai_base_url=...` override for each Codex invocation.

## Architecture

Use a multi-stage Alpine image. The builder stage downloads OpenAI's official standalone installer from `https://chatgpt.com/codex/install.sh` and installs the Codex standalone package. The Dockerfile defaults to a pinned Codex release for reproducible builds, while still allowing `--build-arg CODEX_RELEASE=latest` or any supported version. The runtime stage copies only the installed Codex package and a small entrypoint script. Runtime dependencies are limited to certificates, git, bash, and a few standard shell utilities already provided by Alpine.

The container runs as an unprivileged `codex` user with `/workspace` as the default working directory and `/home/codex/.codex` as the default `CODEX_HOME`.

## Runtime Behavior

- With no command, start `codex` interactively.
- If the command starts with a Codex subcommand or flag, prepend `codex`.
- If the command is another executable such as `sh` or `bash`, run it unchanged.
- If `OPENAI_BASE_URL` is set, add `--config openai_base_url='"$OPENAI_BASE_URL"'` before user arguments.
- If `OPENAI_API_KEY` is set and no file-based auth cache exists, try to persist API-key auth with `codex login --with-api-key` using non-interactive stdin. If the installed CLI does not support that exact flag shape, leave the variable untouched and continue so users can still run explicit login commands.

## Files

- `Dockerfile`: multi-stage small image build.
- `docker-entrypoint.sh`: runtime defaults and environment-to-config translation.
- `.dockerignore`: keep local state and secrets out of Docker build context.
- `README.md`: build and run examples.

## Verification

- Build the image with Docker.
- Run `codex --version` inside the image.
- Run a shell command inside the image to verify non-Codex command passthrough.
- Verify `OPENAI_BASE_URL` is accepted without breaking a simple `codex --version` invocation.
