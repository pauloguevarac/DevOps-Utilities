#!/usr/bin/env bash
#
# deploy.sh
# ------------------------------------------------------------------
# Zero-downtime deploy helper: builds, tests, and promotes a release
# to a target environment, with an optional rollback.
#
# Designed to be environment-agnostic (works with Docker/Swarm, K8s,
# or a simple rsync-based deploy) by keeping the core steps explicit.
#
# Usage:
#   ./deploy.sh <env> [--build] [--skip-tests] [--tag <ver>]
#
#   <env>   Target environment (e.g. staging, production)
#
set -euo pipefail

ENV_NAME="${1:-}"
BUILD=0
RUN_TESTS=1
TAG=""

while [[ $# -gt 1 ]]; do
  case "$2" in
    --build)       BUILD=1; shift ;;
    --skip-tests)  RUN_TESTS=0; shift ;;
    --tag)         TAG="$3"; shift 2 ;;
    *)
      echo "Unknown option: $2" >&2
      echo "Usage: $0 <env> [--build] [--skip-tests] [--tag <ver>]" >&2
      exit 1 ;;
  esac
done

if [[ -z "$ENV_NAME" ]]; then
  echo "ERROR: Usage: $0 <env> [options]" >&2
  exit 1
fi

log() { echo "[$(date '+%H:%M:%S')] $*"; }

log "Deploying to environment: $ENV_NAME (tag: ${TAG:-latest})"

[[ "$RUN_TESTS" -eq 1 ]] && { log "Running test suite..."; ./run_tests.sh || { log "Tests FAILED — aborting."; exit 1; }; }
[[ "$BUILD" -eq 1 ]] && { log "Building image/artifact..."; ./build.sh; }

log "Rolling out $ENV_NAME..."
# Placeholder for your actual rollout (docker stack deploy, kubectl apply,
# rsync, etc.). Keep the deploy idempotent and tag-aware.
#   docker stack deploy -c docker-compose.yml "app_$ENV_NAME"
#   kubectl set image deployment/app app=myapp:${TAG:-latest}
echo "  (deploy command for $ENV_NAME here)"

log "Running health check..."
sleep 3
if curl -fsS -o /dev/null "${HEALTH_URL:-http://localhost/health}" 2>/dev/null; then
  log "Health check OK — deploy successful."
else
  log "Health check FAILED — consider rolling back (./rollback.sh $ENV_NAME)." >&2
  exit 1
fi
