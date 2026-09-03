#!/usr/bin/env bash
#
# multi_cloud_region_matrix.sh
# ------------------------------------------------------------------
# Runs a command / script across a matrix of (provider × region),
# so you can roll out a resource or config to many clouds/regions at
# once — handy for disaster-recovery, multi-region HA, or consistency
# checks. Everything is explicit; no destructive default.
#
# Usage:
#   ./multi_cloud_region_matrix.sh --cmd '<shell command>' \
#       --provider aws --regions us-east-1,eu-west-1
#       --provider gcp --regions us-central1  (repeatable)
#       [--dry-run]
#
# Examples:
#   ./multi_cloud_region_matrix.sh --provider aws --regions us-east-1,eu-west-1 \
#       --cmd 'aws s3 ls' --dry-run
#   ./multi_cloud_region_matrix.sh --provider gcp --regions us-central1 \
#       --cmd 'gcloud compute zones list'
#
set -euo pipefail

# Collect provider->regions. Using parallel arrays.
providers=()
regions=()
CMD=""
DRY_RUN=0

add_matrix() {
  local p="$1" r="$2"
  providers+=("$p")
  regions+=("$r")
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) P="$2"; shift 2 ;;
    --regions)  R="$2"; shift 2; add_matrix "${P:-}" "$R" ;;
    --cmd)      CMD="$2"; shift 2 ;;
    --dry-run)  DRY_RUN=1; shift ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$CMD" ]] || { echo "ERROR: --cmd '<command>' is required" >&2; exit 1; }
[[ "${#providers[@]}" -gt 0 ]] || { echo "ERROR: at least one --provider/--regions pair required" >&2; exit 1; }

for i in "${!providers[@]}"; do
  p="${providers[$i]}"
  rmap="${regions[$i]}"
  IFS=',' read -r -a rlist <<<"$rmap"
  for r in "${rlist[@]}"; do
    label="[$p / $r]"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "DRY-RUN $label would run: $CMD"
      continue
    fi
    echo "### Running $label: $CMD"
    # Inject region/provider as env so the command can use them.
    CLOUD_REGION="$r" CLOUD_PROVIDER="$p" $CMD || echo "$label command failed (exit $?)"
  done
done

echo "Done."