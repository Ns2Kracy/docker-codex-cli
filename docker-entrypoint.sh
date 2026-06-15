#!/bin/sh

set -eu

warn() {
  printf 'docker-codex-cli: %s\n' "$1" >&2
}

toml_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

is_codex_subcommand() {
  case "$1" in
    app|app-server|apply|archive|cloud|cloud-tasks|completion|debug|doctor|e|exec|execpolicy|features|fork|login|logout|mcp|mcp-server|plugin|remote-control|resume|sandbox|unarchive|update)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_auth_free_invocation() {
  case "${1:-}" in
    --help|-h|--version|-V|completion|doctor|login|logout)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

codex_config_arg() {
  if [ -n "${OPENAI_BASE_URL:-}" ]; then
    printf 'openai_base_url="%s"' "$(toml_string "$OPENAI_BASE_URL")"
  fi
}

maybe_login_with_api_key() {
  [ -n "${OPENAI_API_KEY:-}" ] || return 0
  [ "${CODEX_AUTO_LOGIN:-1}" != "0" ] || return 0
  [ ! -f "$CODEX_HOME/auth.json" ] || return 0
  is_auth_free_invocation "${1:-}" && return 0

  config_arg="$(codex_config_arg)"

  if [ -n "$config_arg" ]; then
    if printf '%s\n' "$OPENAI_API_KEY" | codex --config "$config_arg" login --api-key >/dev/null 2>&1; then
      return 0
    fi
  else
    if printf '%s\n' "$OPENAI_API_KEY" | codex login --api-key >/dev/null 2>&1; then
      return 0
    fi
  fi

  warn 'OPENAI_API_KEY is set, but automatic `codex login --api-key` did not succeed; continuing with the environment unchanged.'
}

run_codex() {
  maybe_login_with_api_key "${1:-}"

  if [ -n "${OPENAI_API_KEY:-}" ] && [ -z "${CODEX_API_KEY:-}" ]; then
    export CODEX_API_KEY="$OPENAI_API_KEY"
  fi

  config_arg="$(codex_config_arg)"
  if [ -n "$config_arg" ]; then
    set -- --config "$config_arg" "$@"
  fi

  exec codex "$@"
}

export CODEX_HOME="${CODEX_HOME:-/home/codex/.codex}"
mkdir -p "$CODEX_HOME" /workspace

if [ "$#" -eq 0 ]; then
  run_codex
fi

case "$1" in
  codex)
    shift
    run_codex "$@"
    ;;
  -* )
    run_codex "$@"
    ;;
  *)
    if is_codex_subcommand "$1"; then
      run_codex "$@"
    elif command -v "$1" >/dev/null 2>&1; then
      exec "$@"
    else
      run_codex "$@"
    fi
    ;;
esac
