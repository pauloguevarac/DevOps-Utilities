#!/usr/bin/env bash
#
# k8s_tenant_cleanup.sh
# ------------------------------------------------------------------
# Safely removes a tenant Kubernetes namespace and the resources
# created by gke_tenant_namespace.sh (quota, limitrange, netpol).
# Requires an explicit confirmation word — never auto-destroys.
#
# Usage:
#   ./k8s_tenant_cleanup.sh --tenant <name> [--force] [--dry-run]
#
# Examples:
#   ./k8s_tenant_cleanup.sh --tenant acme-corp            # prompts for confirmation
#   ./k8s_tenant_cleanup.sh --tenant acme-corp --force    # skip prompt
#   ./k8s_tenant_cleanup.sh --tenant acme-corp --dry-run  # preview only
#
set -euo pipefail

TENANT=""
FORCE=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)  TENANT="$2"; shift 2 ;;
    --force)   FORCE=1;     shift ;;
    --dry-run) DRY_RUN=1;   shift ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

# Validate tenant name (lowercase alnum start + alnum/._-).
if [[ -z "$TENANT" ]]; then
  echo "ERROR: --tenant <name> is required" >&2
  exit 1
fi
if ! [[ "$TENANT" =~ ^[a-z0-9][a-z0-9._-]{0,62}$ ]]; then
  echo "ERROR: invalid tenant name '$TENANT'" >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not found" >&2
  exit 1
fi

NAMESPACE="$TENANT"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN: would delete namespace '$NAMESPACE' and its resources."
  echo "  kubectl delete namespace $NAMESPACE"
  exit 0
fi

# Confirm unless --force given.
if [[ "$FORCE" -ne 1 ]]; then
  read -r -p "Type the tenant name to confirm deletion of namespace '$NAMESPACE': " answer
  if [[ "$answer" != "$NAMESPACE" ]]; then
    echo "Confirmation mismatch — aborting."
    exit 1
  fi
fi

echo "Deleting namespace '$NAMESPACE'..."
kubectl delete namespace "$NAMESPACE"
echo "Done."
