#!/usr/bin/env bash
#
# cloud_tag_guard.sh
# ------------------------------------------------------------------
# Verifies that cloud resources carry the required tags/labels.
# Useful to ensure your cost-by-tenant scripts actually have data to
# group by — a resource without the "Tenant" tag is invisible to cost
# allocation. Safe: read-only by default.
#
# Supports AWS (tagging) and GCP (compute instances).
#
# Usage:
#   ./cloud_tag_guard.sh --provider aws   [--required Tenant,Env --profile X]
#   ./cloud_tag_guard.sh --provider gcp   [--required tenant,env --project X]
#
set -euo pipefail

PROVIDER=""
REQUIRED=""
PROFILE=""
PROJECT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="$2"; shift 2 ;;
    --required) REQUIRED="$2"; shift 2 ;;
    --profile)  PROFILE="$2";  shift 2 ;;
    --project)  PROJECT="$2";  shift 2 ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$PROVIDER" ]] || { echo "ERROR: --provider aws|gcp is required" >&2; exit 1; }
[[ -n "$REQUIRED" ]] || REQUIRED="Tenant"

IFS=',' read -r -a req_tags <<<"$REQUIRED"

if [[ "$PROVIDER" == "aws" ]]; then
  command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found" >&2; exit 1; }
  profile_args=()
  [[ -n "$PROFILE" ]] && profile_args=(--profile "$PROFILE")
  # Pull all tagged resources (volume, instance, bucket, etc.).
  echo "Checking AWS resources for required tags: ${req_tags[*]}"
  aws resourcegroupstaggingapi get-resources ${profile_args[@]+"${profile_args[@]}"} \
    --query 'ResourceTagMappingList[].{ARN:ResourceARN,Tags:Tags}' --output json 2>/dev/null \
    | REQUIRED="$REQUIRED" python3 -c '
import sys, json, os
req=[t.lower() for t in os.environ["REQUIRED"].split(",")]
try:
    data=json.load(sys.stdin)
except Exception:
    print("Could not read AWS resource-tag data (check permissions)."); sys.exit(0)
missing=0
for r in data:
    arn=r.get("ARN","")
    have={t["Key"].lower() for t in r.get("Tags",[])}
    got=[t for t in req if t not in have]
    if got:
        missing+=1
        print(f"MISSING {got} on {arn}")
print(f"Scanned {len(data)} resources; {missing} missing required tags.")
'

elif [[ "$PROVIDER" == "gcp" ]]; then
  command -v gcloud >/dev/null 2>&1 || { echo "ERROR: gcloud CLI not found" >&2; exit 1; }
  projargs=()
  [[ -n "$PROJECT" ]] && projargs=(--project "$PROJECT")
  echo "Checking GCP compute instances for required labels: ${req_tags[*]}"
  gcloud compute instances list ${projargs[@]+"${projargs[@]}"} --format="table(name,labels)" 2>/dev/null \
    | REQUIRED="$REQUIRED" python3 -c '
import sys, re, os
req=[t.lower() for t in os.environ["REQUIRED"].split(",")]
lines=[l for l in sys.stdin if l.strip()]
instances=lines[1:] if len(lines)>1 else []
missing=0
for line in instances:
    name=line.split()[0] if line.split() else "?"
    low=line.lower()
    got=[t for t in req if t in low]
    if got:
        # present only if "key=value" pattern appears with that key
        present=[t for t in req if re.search(rf"{t}\s*=", low)]
        missing_here=[t for t in req if t not in present]
        if missing_here:
            missing+=1
            print(f"MISSING {missing_here} on {name}")
print(f"Scanned {len(instances)} instances; {missing} missing required labels.")
'
else
  echo "ERROR: --provider must be aws or gcp" >&2
  exit 1
fi