#!/usr/bin/env bash
#
# terraform_plan_report.sh
# ------------------------------------------------------------------
# Runs `terraform plan` (optionally chdir) and prints a short,
# PR-friendly summary of the change counts, plus a filtered diff.
#
# Usage:
#   ./terraform_plan_report.sh [--dir <path>] [--out tfplan] [--format text|md]
#
# Examples:
#   ./terraform_plan_report.sh --dir terraform/prod --format md
#
set -euo pipefail

DIR="."
OUT=""
FORMAT="text"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)    DIR="$2";    shift 2 ;;
    --out)    OUT="$2";    shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ "$FORMAT" == "text" || "$FORMAT" == "md" ]] || { echo "ERROR: --format must be text|md" >&2; exit 1; }

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform CLI not found" >&2
  exit 1
fi
[[ -d "$DIR" ]] || { echo "ERROR: directory not found: $DIR" >&2; exit 1; }

cd "$DIR"

# Build plan args.
plan_args=(-input=false)
if [[ -n "$OUT" ]]; then
  plan_args+=(-out="$OUT")
fi

# Capture plan output (tee to keep for parsing).
plan_log=$(mktemp)
terraform plan "${plan_args[@]}" 2>&1 | tee "$plan_log"

# Parse the summary line "Plan: X to add, Y to change, Z to destroy."
summary=$(grep -E "Plan: [0-9]+ to add" "$plan_log" | tail -1 || true)

add=$(  sed -nE 's/.*([0-9]+) to add.*/\1/p'   <<<"$summary" || echo 0)
chg=$(  sed -nE 's/.*([0-9]+) to change.*/\1/p' <<<"$summary" || echo 0)
del=$(  sed -nE 's/.*([0-9]+) to destroy.*/\1/p' <<<"$summary" || echo 0)
add=${add:-0}; chg=${chg:-0}; del=${del:-0}

echo
echo "=== Terraform plan report ($DIR) ==="
if [[ "$FORMAT" == "md" ]]; then
  printf '| Action | Count |\n|--------|-------|\n| to add | %s |\n| to change | %s |\n| to destroy | %s |\n' "$add" "$chg" "$del"
else
  printf 'to add:    %s\nto change: %s\nto destroy:%s\n' "$add" "$chg" "$del"
fi

# Show the changed resources (+/-/~ lines) for a PR diff.
echo
echo "Changed resources:"
grep -E "^[[:space:]]*[+~-][[:space:]]*(aws_|google_|azurerm_|kubernetes_|module\.|# )" "$plan_log" | head -40 || true

rm -f "$plan_log"
