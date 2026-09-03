#!/usr/bin/env bash
#
# terraform_check.sh
# ------------------------------------------------------------------
# Runs a standard pre-apply sanity check across Terraform
# directories: fmt check, init, validate, and plan.
# Fails fast so broken configs never reach production.
#
# Usage:
#   ./terraform_check.sh [--dir <path>] [--plan] [--destroy]
#
#   --dir <path>   Terraform directory to check (default: current dir)
#   --plan         Run `terraform plan` (needs credentials)
#   --destroy      Pass -destroy to the plan (caution: destructive preview)
#
set -euo pipefail

TF_DIR="."
PLAN=0
DESTROY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)    TF_DIR="$2"; shift 2 ;;
    --plan)   PLAN=1; shift ;;
    --destroy) DESTROY=1; shift ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [--dir <path>] [--plan] [--destroy]" >&2
      exit 1 ;;
  esac
done

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform CLI not found." >&2
  exit 1
fi

echo "=== Terraform check: $TF_DIR ==="
cd "$TF_DIR"

echo "--- terraform fmt (check) ---"
terraform fmt -check -diff .

echo "--- terraform init ---"
terraform init -input=false -backend=false 2>/dev/null || terraform init -input=false

echo "--- terraform validate ---"
terraform validate

if [[ "$PLAN" -eq 1 ]]; then
  echo "--- terraform plan ---"
  plan_args=("-input=false")
  [[ "$DESTROY" -eq 1 ]] && plan_args+=("-destroy")
  terraform plan "${plan_args[@]}" -out=tfplan
fi

echo "=== All checks passed for $TF_DIR ==="
