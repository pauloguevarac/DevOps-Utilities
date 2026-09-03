#!/usr/bin/env bash
#
# backup_to_s3_gcs.sh
# ------------------------------------------------------------------
# Uploads a local directory to AWS S3 (versioned) and/or GCS
# (object lifecycle), tagging/prefixing by tenant. Safe dry-run.
#
# Usage:
#   ./backup_to_s3_gcs.sh --tenant <name> --source <dir>
#                        [--s3-bucket <b>] [--gcs-bucket <b>]
#                        [--profile X] [--project Y] [--dry-run]
#
# At least one of --s3-bucket or --gcs-bucket is required.
#
set -euo pipefail

TENANT=""
SOURCE=""
S3_BUCKET=""
GCS_BUCKET=""
PROFILE=""
PROJECT=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)     TENANT="$2";     shift 2 ;;
    --source)     SOURCE="$2";     shift 2 ;;
    --s3-bucket)  S3_BUCKET="$2";  shift 2 ;;
    --gcs-bucket) GCS_BUCKET="$2"; shift 2 ;;
    --profile)    PROFILE="$2";    shift 2 ;;
    --project)    PROJECT="$2";    shift 2 ;;
    --dry-run)    DRY_RUN=1;       shift ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$TENANT" ]] || { echo "ERROR: --tenant <name> is required" >&2; exit 1; }
if ! [[ "$TENANT" =~ ^[a-z0-9][a-z0-9._-]{0,62}$ ]]; then
  echo "ERROR: invalid tenant name '$TENANT'" >&2; exit 1
fi
[[ -n "$SOURCE" && -d "$SOURCE" ]] || { echo "ERROR: --source <dir> is required and must exist" >&2; exit 1; }
[[ -n "$S3_BUCKET" || -n "$GCS_BUCKET" ]] || { echo "ERROR: provide --s3-bucket and/or --gcs-bucket" >&2; exit 1; }
[[ -n "$S3_BUCKET" ]] && { command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found" >&2; exit 1; }; }
[[ -n "$GCS_BUCKET" ]] && { command -v gsutil >/dev/null 2>&1 || { echo "ERROR: gsutil not found" >&2; exit 1; }; }

TARGET="${SOURCE%/}-$(date +%Y%m%d)"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "DRY-RUN:"
  [[ -n "$S3_BUCKET" ]] && echo "  aws s3 sync \"$SOURCE\" \"s3://$S3_BUCKET/$TENANT/$TARGET/\""
  [[ -n "$GCS_BUCKET" ]] && echo "  gsutil rsync -r \"$SOURCE\" \"gs://$GCS_BUCKET/$TENANT/$TARGET/\""
  exit 0
fi

if [[ -n "$S3_BUCKET" ]]; then
  echo "Backing up $SOURCE -> s3://$S3_BUCKET/$TENANT/$TARGET/"
  aws s3 sync "$SOURCE" "s3://$S3_BUCKET/$TENANT/$TARGET/" ${PROFILE:+--profile "$PROFILE"}
fi

if [[ -n "$GCS_BUCKET" ]]; then
  echo "Backing up $SOURCE -> gs://$GCS_BUCKET/$TENANT/$TARGET/"
  gsutil -m rsync -r "$SOURCE" "gs://$GCS_BUCKET/$TENANT/$TARGET/" ${PROJECT:+-p "$PROJECT"}
fi

echo "Backup complete."