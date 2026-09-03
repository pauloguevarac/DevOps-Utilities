#!/usr/bin/env bash
#
# cleanup_logs.sh
# ------------------------------------------------------------------
# Cleans up old / large log files under a directory, with a
# dry-run mode so you can preview what will be deleted.
#
# Usage:
#   ./cleanup_logs.sh <log_dir> [--older-than Ndays] [--larger-than SIZE] [--dry-run]
#
#   --older-than Ndays   Delete files not modified in the last N days (default: 30)
#   --larger-than SIZE   Also delete files bigger than SIZE (e.g. 100M, 2G). Optional.
#   --dry-run            Only print what would be deleted, delete nothing.
#
set -euo pipefail

LOG_DIR="${1:-}"
DAYS=30
SIZE_FILTER=""
DRY_RUN=0

while [[ $# -gt 1 ]]; do
  case "$2" in
    --older-than)
      DAYS="$3"; shift 2 ;;
    --larger-than)
      SIZE_FILTER="-size +$3"; shift 2 ;;
    --dry-run)
      DRY_RUN=1; shift ;;
    *)
      echo "Unknown option: $2" >&2
      exit 1 ;;
  esac
done

if [[ -z "$LOG_DIR" || ! -d "$LOG_DIR" ]]; then
  echo "ERROR: Usage: $0 <log_dir> [options]" >&2
  exit 1
fi

echo "=== Cleaning logs in: $LOG_DIR (older than ${DAYS} days) ==="

# Build find expression with a while-read loop.
# (Avoid `mapfile` — not available on macOS bash 3.2.)
candidates=()
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  candidates+=("$f")
done < <(
  find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.out" -o -name "*.txt" \) \
       ${SIZE_FILTER:-} -mtime "+$DAYS" -print 2>/dev/null
)

if [[ "${#candidates[@]}" -eq 0 ]]; then
  echo "Nothing to clean."
  exit 0
fi

echo "Found ${#candidates[@]} candidate file(s)."
for f in "${candidates[@]}"; do
  size=$(du -h "$f" | cut -f1)
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  [DRY-RUN] would delete: $f ($size)"
  else
    echo "  Deleting: $f ($size)"
    rm -f -- "$f"
  fi
done

[[ "$DRY_RUN" -eq 1 ]] && echo "(dry run — nothing deleted)" || echo "Cleanup complete."
