#!/usr/bin/env bash

set -euo pipefail

COMMANDS=(tix noc-start noc-status noc-inv noc-handover)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"
INSTALL_DIR="${NOC_TOOLS_INSTALL_DIR:-$HOME/.local/bin}"

[[ -d "$BIN_DIR" ]] || {
  echo "ERROR: release bin directory is missing." >&2
  exit 1
}

mkdir -p "$INSTALL_DIR"
for command in "${COMMANDS[@]}"; do
  source_file="$BIN_DIR/$command"
  [[ -f "$source_file" ]] || {
    echo "ERROR: release command is missing: $command" >&2
    exit 1
  }
  bash -n "$source_file"
done

for command in "${COMMANDS[@]}"; do
  temporary="$INSTALL_DIR/.${command}.install.$$"
  install -m 755 "$BIN_DIR/$command" "$temporary"
  bash -n "$temporary"
  mv -f "$temporary" "$INSTALL_DIR/$command"
done

printf 'Installed noc-tools commands in %s\n' "$INSTALL_DIR"
