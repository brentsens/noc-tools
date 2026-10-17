#!/usr/bin/env bash
# rollback.sh - restore installed NOC tools from an install.sh backup
# Usage: ./rollback.sh [--list | latest | BACKUP_DIRECTORY]
set -euo pipefail

INSTALL_DIR="$HOME/.local/bin"
BACKUP_ROOT="$HOME/.local/share/noc-tools/backups"
ROLLBACK_BACKUP_ROOT="$HOME/.local/share/noc-tools/rollback-safety"
TOOLS=(noc-start noc-status noc-doctor noc-test noc-inv noc-handover tix)

ok(){ printf '  [OK] %s\n' "$1"; }
warn(){ printf '  [WARN] %s\n' "$1"; }
fail(){ printf '  [ERROR] %s\n' "$1" >&2; exit 1; }

list_backups(){
  echo "Available installer backups:"
  if [ ! -d "$BACKUP_ROOT" ]; then
    echo "  None. Backup root does not exist: $BACKUP_ROOT"
    return 0
  fi
  mapfile -t dirs < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort -r)
  if [ ${#dirs[@]} -eq 0 ]; then echo "  None"; return 0; fi
  for d in "${dirs[@]}"; do
    count=0
    for tool in "${TOOLS[@]}"; do [ -f "$d/$tool" ] && count=$((count+1)); done
    printf '  %s  (%d tool backup%s)\n' "$d" "$count" "$([ "$count" -eq 1 ] && echo '' || echo 's')"
  done
}

case "${1:-}" in
  --list|-l) list_backups; exit 0 ;;
  latest|"")
    [ -d "$BACKUP_ROOT" ] || fail "No installer backup directory exists"
    BACKUP_DIR=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort -r | head -n1)
    [ -n "$BACKUP_DIR" ] || fail "No installer backups found"
    ;;
  *) BACKUP_DIR="$1" ;;
esac

[ -d "$BACKUP_DIR" ] || fail "Backup directory not found: $BACKUP_DIR"

RESTORE_TOOLS=()
for tool in "${TOOLS[@]}"; do
  if [ -f "$BACKUP_DIR/$tool" ]; then RESTORE_TOOLS+=("$tool"); fi
done
[ ${#RESTORE_TOOLS[@]} -gt 0 ] || fail "Backup contains none of the expected NOC tools"

# Validate all backup files before touching live tools.
echo
echo "=== NOC TOOLS ROLLBACK ==="
echo "Source backup: $BACKUP_DIR"
echo
echo "[1] Validating backup"
for tool in "${RESTORE_TOOLS[@]}"; do
  bash -n "$BACKUP_DIR/$tool" || fail "$tool backup failed Bash syntax validation"
  ok "$tool"
done

# Preview exact files that will change.
echo
echo "[2] Rollback preview"
for tool in "${RESTORE_TOOLS[@]}"; do
  if [ -f "$INSTALL_DIR/$tool" ]; then
    if cmp -s "$BACKUP_DIR/$tool" "$INSTALL_DIR/$tool"; then
      printf '  [UNCHANGED] %s\n' "$tool"
    else
      printf '  [RESTORE]   %s\n' "$tool"
    fi
  else
    printf '  [RESTORE]   %s (currently missing)\n' "$tool"
  fi
done

CHANGED=()
for tool in "${RESTORE_TOOLS[@]}"; do
  if [ ! -f "$INSTALL_DIR/$tool" ] || ! cmp -s "$BACKUP_DIR/$tool" "$INSTALL_DIR/$tool"; then CHANGED+=("$tool"); fi
done
if [ ${#CHANGED[@]} -eq 0 ]; then
  echo; echo "No rollback required. Installed tools already match this backup."; exit 0
fi

read -rp "Restore ${#CHANGED[@]} tool(s) from this backup? [y/N]: " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Canceled. Nothing was changed."; exit 0; }

# Create a safety copy of the current live files so this rollback can itself be reversed.
STAMP=$(date '+%Y%m%d-%H%M%S')
SAFETY_DIR="$ROLLBACK_BACKUP_ROOT/$STAMP"
mkdir -p "$SAFETY_DIR" "$INSTALL_DIR"
for tool in "${CHANGED[@]}"; do
  [ -f "$INSTALL_DIR/$tool" ] && cp -p "$INSTALL_DIR/$tool" "$SAFETY_DIR/$tool"
done
ok "Current live versions saved to $SAFETY_DIR"

# Restore atomically, one validated tool at a time.
echo
echo "[3] Restoring"
for tool in "${CHANGED[@]}"; do
  temp="$INSTALL_DIR/.${tool}.rollback.$$"
  cp "$BACKUP_DIR/$tool" "$temp"
  chmod 755 "$temp"
  bash -n "$temp" || { rm -f "$temp"; fail "$tool restored copy failed validation"; }
  mv "$temp" "$INSTALL_DIR/$tool"
  ok "$tool"
done

# Validate the restored installed stack. Doctor warnings are acceptable; failures are not.
echo
echo "[4] Validating restored stack"
if [ -x "$INSTALL_DIR/noc-doctor" ]; then
  if "$INSTALL_DIR/noc-doctor" --deep; then
    ok "noc-doctor completed"
  else
    fail "Restored stack failed noc-doctor. Pre-rollback files are in $SAFETY_DIR"
  fi
else
  warn "noc-doctor unavailable after rollback; run manual validation"
fi

echo
echo "Rollback completed."
echo "Restored from: $BACKUP_DIR"
echo "Pre-rollback safety copy: $SAFETY_DIR"
