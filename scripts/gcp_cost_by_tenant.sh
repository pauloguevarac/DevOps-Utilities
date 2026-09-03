#!/usr/bin/env bash
#
# gcp_cost_by_tenant.sh
# ------------------------------------------------------------------
# Reports GCP costs grouped by a "tenant" label using the BigQuery
# billing export, so a SaaS/ISP can answer "what does each tenant
# cost this month?".
#
# Requires:
#   - gcloud CLI + bq CLI installed and authenticated
#   - BigQuery billing export enabled for the project
#
# Usage:
#   ./gcp_cost_by_tenant.sh --table <project.dataset.table>
#                           [--label tenant] [--start YYYY-MM] [--end YYYY-MM]
#                           [--dry-run]
#
# Examples:
#   ./gcp_cost_by_tenant.sh --table myproj.billing.gcp_billing_export_v1_XXXX
#   ./gcp_cost_by_tenant.sh --table ... --start 2026-08 --dry-run
#
# shellcheck source=common.sh
. "$(dirname "$0")/common.sh"

TABLE=""
LABEL="tenant"
START=""
END=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --table)       TABLE="$2";       shift 2 ;;
    --label)       LABEL="$2";       shift 2 ;;
    --start)       START="$2";       shift 2 ;;
    --end)         END="$2";         shift 2 ;;
    --dry-run)     DRY_RUN=1;        shift ;;
    *) die "unknown option: $1 (see header for usage)" ;;
  esac
done

[[ -n "$TABLE" ]] || die "--table <project.dataset.table> is required"
if ! [[ "$LABEL" =~ ^[A-Za-z][A-Za-z0-9_-]{0,63}$ ]]; then
  die "invalid label name '$LABEL'"
fi

[[ -n "$START" ]] || START="$(date '+%Y-%m')-01"
[[ -n "$END" ]]   || END="$(date '+%Y-%m')-31"

# Build a query against the standard BigQuery billing export schema.
query=$(cat <<EOF
SELECT
  label.value AS tenant,
  ROUND(SUM(cost), 2) AS total_cost,
  ROUND(SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) c), 0)), 2) AS credits
FROM \`$TABLE\`
CROSS JOIN UNNEST(labels) AS label
WHERE label.key = '$LABEL'
  AND invoice.month BETWEEN '${START:0:7}' AND '${END:0:7}'
GROUP BY tenant
ORDER BY total_cost DESC
EOF
)

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY-RUN: would run bq query against '$TABLE' (label: '$LABEL'):"
  printf '%s\n' "$query"
  exit 0
fi

require_cmd bq
log "Fetching GCP cost by label '$LABEL' from '$TABLE'..."
bq query --use_legacy_sql=false --format=pretty --max_rows=100 "$query"
