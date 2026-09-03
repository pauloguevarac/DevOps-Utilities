#!/usr/bin/env bash
#
# rotate_cloud_creds.sh
# ------------------------------------------------------------------
# Lists access keys / service accounts older than a threshold so you
# can rotate stale credentials. Security-gap finder, read-only by
# default (--apply performs the rotation).
#
# Usage:
#   ./rotate_cloud_creds.sh --provider aws [--max-age 90 --profile X] [--apply]
#   ./rotate_cloud_creds.sh --provider gcp [--max-age 90 --project X] [--apply]
#
set -euo pipefail

PROVIDER=""
MAX_AGE=90
PROFILE=""
PROJECT=""
APPLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --max-age)  MAX_AGE="$2";  shift 2 ;;
    --profile)  PROFILE="$2";  shift 2 ;;
    --project)  PROJECT="$2";  shift 2 ;;
    --apply)    APPLY=1;       shift ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PROVIDER" ]] || { echo "ERROR: --provider aws|gcp is required" >&2; exit 1; }

if [[ "$PROVIDER" == "aws" ]]; then
  command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found" >&2; exit 1; }
  pa=()
  [[ -n "$PROFILE" ]] && pa=(--profile "$PROFILE")
  echo "Checking AWS IAM access keys older than $MAX_AGE days..."
  # Users with their access keys list.
  # shellcheck disable=SC2016
  for user in $(aws iam list-users --query 'Users[].UserName' --output text ${pa[@]+"${pa[@]}"}); do
    # the JMESPath below is literal (single quotes) — shellcheck SC2016 disabled
    # shellcheck disable=SC2016
    aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[?Status==`Active`].{k:AccessKeyId,d:CreateDate}' --output text ${pa[@]+"${pa[@]}"} \
      | while read -r key created; do
          # crude age check via date
          created_ts=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created" "+%s" 2>/dev/null || date -d "$created" "+%s" 2>/dev/null || echo 0)
          now=$(date "+%s")
          age=$(( (now - created_ts) / 86400 ))
          if [[ "$age" -ge "$MAX_AGE" ]]; then
            echo "STALE: user=$user key=$key age=${age}d (created $created)"
            if [[ "$APPLY" -eq 1 ]]; then
              echo -n "  -> deactivating... "
              aws iam update-access-key --user-name "$user" --access-key-id "$key" --status Inactive ${pa[@]+"${pa[@]}"}
              echo "done."
            fi
          fi
        done
  done

elif [[ "$PROVIDER" == "gcp" ]]; then
  command -v gcloud >/dev/null 2>&1 || { echo "ERROR: gcloud CLI not found" >&2; exit 1; }
  projargs=()
  [[ -n "$PROJECT" ]] && projargs=(--project "$PROJECT")
  echo "Checking GCP service-account keys (creation date is not exposed; listing keys needing attention)..."
  for sa in $(gcloud iam service-accounts list --format="value(email)" ${projargs[@]+"${projargs[@]}"}); do
    keys=$(gcloud iam service-accounts keys list --iam-account="$sa" --format="value(name)" ${projargs[@]+"${projargs[@]}"} 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$keys" -gt 1 ]]; then
      echo "STALE: service-account $sa has $keys keys (best practice: rotate to one)."
      # NOTE: deletion requires --apply and choosing which key; we just warn by default.
    fi
  done
  [[ "$APPLY" -eq 1 ]] && echo "GCP key rotation not automated here by default — use the console or keyIds explicitly."

else
  echo "ERROR: --provider must be aws or gcp" >&2
  exit 1
fi

echo "Done."