#!/usr/bin/env bash
#
# common.sh — shared helpers for DevOps-Utilities cloud scripts.
# Source from scripts: . "$(dirname "$0")/common.sh"
#
set -euo pipefail

log() { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Validate a tenant name: lowercase alnum start, then alnum/._- , 1-63 chars.
# Prevents injection into commands/labels.
validate_tenant() {
  local t="${1:-}"
  [[ -n "$t" ]] || die "tenant name is required"
  if ! [[ "$t" =~ ^[a-z0-9][a-z0-9._-]{0,62}$ ]]; then
    die "invalid tenant name '$t' (use lowercase alnum, dots, dashes, underscores; 1-63 chars)"
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "required CLI '$cmd' not found in PATH"
  fi
}
