#!/bin/sh

set -eu

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

run_codex() {
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
