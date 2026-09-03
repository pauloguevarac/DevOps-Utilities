#!/usr/bin/env bash
#
# docker_prune_safe.sh
# ------------------------------------------------------------------
# Dry-run by default: shows what `docker system prune` would remove
# BEFORE actually pruning. Uses `--dry-run` (docker 24+), or a manual
# simulation otherwise. Deletes only with an explicit --confirm flag.
#
# Usage:
#   ./docker_prune_safe.sh [--all] [--volumes] [--confirm]
#
#   --all        Also prune unused images (not just dangling).
#   --volumes    Also prune unused volumes (CAUTION: data loss).
#   --confirm    Actually run the prune (default is dry-run only).
#
set -euo pipefail

ALL=""
VOLUMES=""
CONFIRM=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)     ALL="--all"; shift ;;
    --volumes) VOLUMES="--volumes"; shift ;;
    --confirm) CONFIRM=1; shift ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker not found" >&2; exit 1; }

prune_args=(-f)
[[ -n "$ALL" ]] && prune_args+=("$ALL")
[[ -n "$VOLUMES" ]] && prune_args+=("$VOLUMES")

# Docker 24+ supports --dry-run on system prune.
dry_supported=$(docker system prune --help 2>/dev/null | grep -c -- --dry-run || true)

if [[ "$dry_supported" -gt 0 ]]; then
  echo "=== Previewing prune (dry-run) ==="
  docker system prune "${prune_args[@]}" --dry-run
else
  # Simulate: report dangling images / unused volumes without deleting.
  echo "=== Previewing prune (docker < 24, simulated) ==="
  echo "Dangling images:"; docker images -f "dangling=true" -q 2>/dev/null
  [[ -n "$VOLUMES" ]] && { echo "Unused volumes:"; docker volume ls -f "dangling=true" -q 2>/dev/null; }
fi

if [[ "$CONFIRM" -ne 1 ]]; then
  echo
  echo "Dry-run only — nothing deleted. Re-run with --confirm to actually prune."
  exit 0
fi

read -r -p "Type YES to permanently prune${VOLUMES:+ (including volumes — data loss!)}: " answer
[[ "$answer" == "YES" ]] || { echo "Aborted."; exit 1; }

echo "Pruning..."
docker system prune "${prune_args[@]}"
echo "Done."