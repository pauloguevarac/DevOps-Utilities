#!/usr/bin/env bash
#
# aws_tenant_provision.sh
# ------------------------------------------------------------------
# Provisions isolated, tagged AWS resources for a tenant in a
# multi-tenant SaaS environment:
#   - S3 bucket per tenant (with server-side encryption)
#   - IAM policy scoped to that tenant's bucket (least privilege)
#
# Everything is tagged with the tenant name + ManagedBy so cost
# allocation and audits are trivial. Idempotent: safe to re-run.
#
# Requires:
#   - AWS CLI installed + credentials
#
# Usage:
#   ./aws_tenant_provision.sh --tenant <name> [--prefix <prefix>]
#                             [--region <region>] [--profile <name>] [--dry-run]
#
# Examples:
#   ./aws_tenant_provision.sh --tenant acme-corp
#   ./aws_tenant_provision.sh --tenant acme-corp --prefix saas-data --dry-run
#
. "$(dirname "$0")/common.sh"

TENANT=""
PREFIX="saas"
REGION="us-east-1"
PROFILE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tenant)  TENANT="$2";  shift 2 ;;
    --prefix)  PREFIX="$2";  shift 2 ;;
    --region)  REGION="$2";  shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1;    shift ;;
    *) die "unknown option: $1 (see header for usage)" ;;
  esac
done

validate_tenant "$TENANT"
if ! [[ "$PREFIX" =~ ^[a-z0-9-]{1,30}$ ]]; then
  die "invalid prefix '$PREFIX'"
fi

BUCKET="${PREFIX}-${TENANT}"
POLICY_NAME="tenant-${TENANT}-s3"
TAG_SET="Tenant=${TENANT},ManagedBy=DevOps-Utilities"

region_args=()
if [[ -n "$PROFILE" ]]; then
  profile_args=(--profile "$PROFILE")
else
  profile_args=()
fi

# NOTE: --region is passed explicitly in commands; --profile appended when set.

build_cmds() {
  # 1) Create the bucket (ignore "already exists").
  echo "aws s3api create-bucket --bucket \"$BUCKET\" --region \"$REGION\""
  # 2) Apply tags for cost allocation.
  echo "aws s3api put-bucket-tagging --bucket \"$BUCKET\" --tagging 'TagSet=[{Key=Tenant,Value=$TENANT},{Key=ManagedBy,Value=DevOps-Utilities}]'"
  # 3) Enable default encryption.
  echo "aws s3api put-bucket-encryption --bucket \"$BUCKET\" --server-side-encryption-configuration '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}'"
  # 4) Tenant-scoped IAM policy (least privilege on just this bucket).
  echo "aws iam create-policy --policy-name \"$POLICY_NAME\" --policy-document '{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:PutObject\",\"s3:ListBucket\"],\"Resource\":[\"arn:aws:s3:::$BUCKET\",\"arn:aws:s3:::$BUCKET/*\"]}]}'"
}

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "DRY-RUN: would run these commands for tenant '$TENANT':"
  while IFS= read -r line; do
    [[ -n "$line" ]] && printf '  %s\n' "$line"
  done < <(build_cmds)
  exit 0
fi

require_cmd aws
log "Provisioning tenant '$TENANT' (bucket: $BUCKET)..."

# 1) Create bucket if it doesn't exist.
if ! aws s3api head-bucket --bucket "$BUCKET" ${profile_args[@]+"${profile_args[@]}"} 2>/dev/null; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" ${profile_args[@]+"${profile_args[@]}"}
fi

aws s3api put-bucket-tagging --bucket "$BUCKET" \
  --tagging "TagSet=[{Key=Tenant,Value=$TENANT},{Key=ManagedBy,Value=DevOps-Utilities}]" \
  ${profile_args[@]+"${profile_args[@]}"}

aws s3api put-bucket-encryption --bucket "$BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  ${profile_args[@]+"${profile_args[@]}"}

log "Creating tenant-scoped IAM policy: $POLICY_NAME"
aws iam create-policy --policy-name "$POLICY_NAME" \
  --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\",\"s3:PutObject\",\"s3:ListBucket\"],\"Resource\":[\"arn:aws:s3:::$BUCKET\",\"arn:aws:s3:::$BUCKET/*\"]}]}" \
  ${profile_args[@]+"${profile_args[@]}"}

log "Tenant '$TENANT' provisioned: bucket=$BUCKET, policy=$POLICY_NAME"
