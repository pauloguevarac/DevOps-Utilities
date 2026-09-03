#!/usr/bin/env bash
#
# prometheus_alert_check.sh
# ------------------------------------------------------------------
# Validates Prometheus rule files (alerting + recording) before you
# apply them, using `promtool`. Exits non-zero on any syntax error.
#
# Usage:
#   ./prometheus_alert_check.sh [--files '<rulefile1> <rulefile2>'] [--dir <path>]
#
# Examples:
#   ./prometheus_alert_check.sh --dir prometheus/rules        # check *.yml in dir
#   ./prometheus_alert_check.sh --files alarm.yml recording.yml
#
set -euo pipefail

FILES=""
DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --files) FILES="$2"; shift 2 ;;
    --dir)   DIR="$2";   shift 2 ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

command -v promtool >/dev/null 2>&1 || { echo "ERROR: promtool not found (part of Prometheus)" >&2; exit 1; }

# Resolve file list.
rule_files=()
if [[ -n "$FILES" ]]; then
  read -r -a rule_files <<<"$FILES"
elif [[ -n "$DIR" && -d "$DIR" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    rule_files+=("$f")
  done < <(find "$DIR" \( -name "*.yml" -o -name "*.yaml" \) | sort)
else
  echo "ERROR: provide either --files or --dir" >&2
  exit 1
fi

[[ "${#rule_files[@]}" -gt 0 ]] || { echo "No rule files found."; exit 0; }

fail=0
for f in "${rule_files[@]}"; do
  if promtool check rules "$f"; then
    echo "OK: $f"
  else
    echo "FAIL: $f"
    fail=1
  fi
done

if [[ "$fail" -eq 0 ]]; then
  echo "All rule files valid."
else
  echo "Some rule files failed validation." >&2
  exit 1
fi