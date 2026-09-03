#!/usr/bin/env bash
#
# aws_cost_by_tenant.sh
# ------------------------------------------------------------------
# Reports AWS costs grouped by a "Tenant" cost-allocation tag, so a
# SaaS/ISP can answer "how much does each tenant cost me this month?".
#
# Requires:
#   - AWS CLI installed + credentials configured
#   - Cost Explorer API enabled (ce:GetCostAndUsage)
#   - A cost allocation tag created (e.g. Tenant) in Billing → Cost tags
#
# Usage:
#   ./aws_cost_by_tenant.sh [--tag Tenant] [--start YYYY-MM] [--end YYYY-MM]
#                           [--monthly|--daily] [--profile <name>] [--dry-run]
#
# Examples:
#   ./aws_cost_by_tenant.sh                                   # current month
#   ./aws_cost_by_tenant.sh --tag Tenant --start 2026-08      # August 2026
#   ./aws_cost_by_tenant.sh --daily --dry-run                 # preview only
#
# shellcheck disable=SC1091
. "$(dirname "$0")/common.sh"

TAG="Tenant"
START=""
END=""
GRANULARITY="MONTHLY"
PROFILE=""
DRY_RUN=0

# --- arg parsing -------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)        TAG="$2";      shift 2 ;;
    --start)      START="$2";    shift 2 ;;
    --end)        END="$2";      shift 2 ;;
    --monthly)    GRANULARITY="MONTHLY"; shift ;;
    --daily)      GRANULARITY="DAILY";   shift ;;
    --profile)    PROFILE="$2";  shift 2 ;;
    --dry-run)    DRY_RUN=1;     shift ;;
    *)
      die "unknown option: $1 (see header for usage)"
      ;;
  esac
done

# --- defaults / validation --------------------------------------------
[[ -n "$START" ]] || START="$(date '+%Y-%m-01')"
[[ -n "$END" ]]   || END="$(date -v+1m -v-1d '+%Y-%m-%d' 2>/dev/null \
                             || date -d "$(date +%Y-%m-01) +1 month -1 day" '+%Y-%m-%d' 2>/dev/null \
                             || date '+%Y-%m-%d')"

# Validate the tag name to avoid injecting into the JSON filter.
if ! [[ "$TAG" =~ ^[A-Za-z][A-Za-z0-9_-]{0,63}$ ]]; then
  die "invalid tag name '$TAG'"
fi

profile_args=()
if [[ -n "$PROFILE" ]]; then
  profile_args=(--profile "$PROFILE")
fi

# --- build Cost Explorer request ---------------------------------------
cmd=(aws ce get-cost-and-usage ${profile_args[@]+"${profile_args[@]}"} \
     --time-period "Start=$START,End=$END" \
     --granularity "$GRANULARITY" \
     --metrics UnblendedCost \
     --group-by "Type=TAG,Key=$TAG")

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY-RUN: would run:"
  printf '  %s\n' "${cmd[*]}"
  exit 0
fi

require_cmd aws
log "Fetching AWS cost by tag '$TAG' ($START .. $END, $GRANULARITY)..."
"${cmd[@]}"
