#!/bin/sh

set -eu

CODEX_REAL_BIN="${CODEX_REAL_BIN:-/usr/local/bin/codex-real}"
export CODEX_HOME="${CODEX_HOME:-/home/codex/.codex}"
mkdir -p "$CODEX_HOME" 2>/dev/null || true

warn() {
  printf 'docker-codex-cli: %s\n' "$1" >&2
}

toml_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

is_auth_free_invocation() {
  case "${1:-}" in
    --help|-h|--version|-V|completion|doctor|login|logout)
      return 0
      ;;
  esac

  for arg in "$@"; do
    case "$arg" in
      --help|-h)
        return 0
        ;;
    esac
  done

  return 1
}

codex_config_arg() {
  if [ -n "${OPENAI_BASE_URL:-}" ]; then
    printf 'openai_base_url="%s"' "$(toml_string "$OPENAI_BASE_URL")"
  fi
}

has_openai_base_url_config() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --config|-c)
        shift
        if [ "$#" -eq 0 ]; then
          return 1
        fi
        case "$1" in
          *openai_base_url*) return 0 ;;
        esac
        ;;
      --config=*|-c=*)
        case "${1#*=}" in
          *openai_base_url*) return 0 ;;
        esac
        ;;
    esac
    shift
  done

  return 1
}

run_codex_for_login() {
  config_arg="$(codex_config_arg)"

  if [ -n "$config_arg" ]; then
    "$CODEX_REAL_BIN" --config "$config_arg" "$@"
  else
    "$CODEX_REAL_BIN" "$@"
  fi
}

maybe_login_with_api_key() {
  [ -n "${OPENAI_API_KEY:-}" ] || return 0
  [ "${CODEX_AUTO_LOGIN:-1}" != "0" ] || return 0
  [ ! -f "$CODEX_HOME/auth.json" ] || return 0
  is_auth_free_invocation "$@" && return 0

  if printf '%s\n' "$OPENAI_API_KEY" | run_codex_for_login login --with-api-key >/dev/null 2>&1; then
    return 0
  fi

  warn 'OPENAI_API_KEY is set, but automatic `codex login --with-api-key` did not succeed; continuing with the environment unchanged.'
}

if [ -n "${OPENAI_API_KEY:-}" ] && [ -z "${CODEX_API_KEY:-}" ]; then
  export CODEX_API_KEY="$OPENAI_API_KEY"
fi

maybe_login_with_api_key "$@"

config_arg="$(codex_config_arg)"
if [ -n "$config_arg" ] && ! has_openai_base_url_config "$@"; then
  exec "$CODEX_REAL_BIN" --config "$config_arg" "$@"
fi

exec "$CODEX_REAL_BIN" "$@"
