#!/usr/bin/env bash
#
# rotate_backups.sh
# ------------------------------------------------------------------
# Rotates local/directory backups, keeping the N most recent.
# Deletes older backups so disk usage stays under control.
#
# Usage:
#   ./rotate_backups.sh <backup_dir> [keep]
#
#   backup_dir   Directory containing dated backups (e.g. site-backup-2026-09-03)
#   keep         Number of most recent backups to keep (default: 7)
#
# Examples:
#   ./rotate_backups.sh /data/backups 7
#   ./rotate_backups.sh /data/backups 30
#
set -euo pipefail

BACKUP_DIR="${1:-}"
KEEP="${2:-7}"

if [[ -z "$BACKUP_DIR" || ! -d "$BACKUP_DIR" ]]; then
  echo "ERROR: Usage: $0 <backup_dir> [keep]" >&2
  exit 1
fi

if ! [[ "$KEEP" =~ ^[0-9]+$ ]] || [[ "$KEEP" -lt 1 ]]; then
  echo "ERROR: 'keep' must be a positive integer." >&2
  exit 1
fi

# List backups (files/dirs), newest first.
# (Use a while-read loop + break; `mapfile`/`read -d ''` are unreliable on
#  macOS bash 3.2 and with `set -o pipefail`.)
backups=()
while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue
  backups+=("$entry")
  [[ "${#backups[@]}" -ge "$KEEP" ]] && break
done < <(ls -1dt "$BACKUP_DIR"/* 2>/dev/null)

count="${#backups[@]}"
echo "Keeping up to $KEEP backups in $BACKUP_DIR (found $count matching)."

# Anything not in the keep-list gets deleted.
keep_set=$(printf '%s\n' "${backups[@]}" || true)
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  if ! grep -Fxq "$entry" <<<"$keep_set"; then
    echo "Removing: $entry"
    rm -rf -- "$entry"
  fi
done < <(ls -1d "$BACKUP_DIR"/* 2>/dev/null)

echo "Backup rotation complete."
