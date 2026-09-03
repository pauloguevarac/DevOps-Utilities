#!/usr/bin/env bash
#
# gke_tenant_namespace.sh
# ------------------------------------------------------------------
# Creates an isolated Kubernetes namespace for a tenant in a
# multi-tenant GKE cluster, with:
#   - namespace labeled with the tenant
#   - a ResourceQuota (CPU/memory limits)
#   - a NetworkPolicy that blocks cross-tenant traffic by default
#   - a default LimitRange so pods must set resource requests
#
# Requires:
#   - kubectl installed, configured for the target GKE cluster
#
# Usage:
#   ./gke_tenant_namespace.sh --tenant <name> [--dry-run]
#
# Examples:
#   ./gke_tenant_namespace.sh --tenant acme-corp
#   ./gke_tenant_namespace.sh --tenant acme-corp --dry-run
#
# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

TENANT=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)  TENANT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1;    shift ;;
    *) die "unknown option: $1 (see header for usage)" ;;
  esac
done

validate_tenant "$TENANT"

NAMESPACE="$TENANT"

# --- manifests ---------------------------------------------------------
quota_yaml=$(cat <<EOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: $NAMESPACE
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    persistentvolumeclaims: "4"
EOF
)

limitrange_yaml=$(cat <<EOF
apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-limitrange
  namespace: $NAMESPACE
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    type: Container
EOF
)

netpol_yaml=$(cat <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-cross-tenant
  namespace: $NAMESPACE
spec:
  podSelector: {}
  policyTypes: ["Ingress", "Egress"]
EOF
)

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN: would run:"
    printf '  %s\n' "$1"
  else
    log "> $1"
    eval "$1"
  fi
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY-RUN: would create namespace '$NAMESPACE' with quota, limitrange & netpol."
fi

run_cmd "kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -"
run_cmd "kubectl label namespace $NAMESPACE tenant=$TENANT managed-by=devops-utilities --overwrite"

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf '\n--- ResourceQuota ---\n%s\n' "$quota_yaml"
  printf '\n--- LimitRange ---\n%s\n' "$limitrange_yaml"
  printf '\n--- NetworkPolicy ---\n%s\n' "$netpol_yaml"
else
  printf '%s\n' "$quota_yaml" | kubectl apply -f -
  printf '%s\n' "$limitrange_yaml" | kubectl apply -f -
  printf '%s\n' "$netpol_yaml" | kubectl apply -f -
fi

log "Tenant namespace '$NAMESPACE' ready."
