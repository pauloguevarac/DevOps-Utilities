#!/usr/bin/env bash
#
# run_tests.sh
# ------------------------------------------------------------------
# Lightweight test harness for the scripts in this repo.
# Each test prints PASS/FAIL and the harness exits non-zero if any fail.
#
set -uo pipefail

PASS=0
FAIL=0

test_rotate_backups() {
  local dir
  dir=$(mktemp -d)
  for i in 1 2 3 4 5; do mkdir -p "$dir/backup-$i"; done
  bash scripts/rotate_backups.sh "$dir" 2 >/dev/null
  local remaining
  remaining=$(ls -1 "$dir" | wc -l | tr -d ' ')
  if [[ "$remaining" -eq 2 ]]; then
    echo "PASS: rotate_backups keeps N most recent ($remaining)"
    PASS=$((PASS+1))
  else
    echo "FAIL: rotate_backups expected 2 remaining, got $remaining"
    FAIL=$((FAIL+1))
  fi
  rm -rf "$dir"
}

test_terraform_check_no_dir() {
  # terraform_check should fail cleanly when terraform CLI is absent or dir missing
  if bash scripts/terraform_check.sh /nonexistent-dir >/dev/null 2>&1; then
    echo "FAIL: terraform_check should fail on missing dir"
    FAIL=$((FAIL+1))
  else
    echo "PASS: terraform_check fails on missing dir"
    PASS=$((PASS+1))
  fi
}

test_cleanup_logs_dry_run() {
  local dir
  dir=$(mktemp -d)
  # set mtime 100 days ago (portable across GNU and macOS touch)
  touch -t "$(date -v-100d '+%Y%m%d%H%M.%S')" "$dir/old.log" 2>/dev/null \
    || touch -d "100 days ago" "$dir/old.log" 2>/dev/null \
    || touch "$dir/old.log"
  touch "$dir/new.log"
  out=$(bash scripts/cleanup_logs.sh "$dir" --older-than 30 --dry-run)
  if grep -q "old.log" <<<"$out" && ! grep -q "new.log" <<<"$out"; then
    echo "PASS: cleanup_logs dry-run flags old log only"
    PASS=$((PASS+1))
  else
    echo "FAIL: cleanup_logs dry-run output unexpected"
    echo "$out"
    FAIL=$((FAIL+1))
  fi
  rm -rf "$dir"
}

test_aws_cost_dry_run() {
  # dry-run must print the aws command with the tag, without needing credentials
  out=$(bash scripts/aws_cost_by_tenant.sh --tag Tenant --dry-run 2>&1)
  if grep -q "aws ce get-cost-and-usage" <<<"$out" && grep -q "Tenant" <<<"$out"; then
    echo "PASS: aws_cost_by_tenant dry-run prints ce command"
    PASS=$((PASS+1))
  else
    echo "FAIL: aws_cost_by_tenant dry-run output unexpected"
    echo "$out"
    FAIL=$((FAIL+1))
  fi
}

test_aws_provision_validation() {
  # invalid tenant name must fail cleanly
  if bash scripts/aws_tenant_provision.sh --tenant "BAD NAME!" --dry-run >/dev/null 2>&1; then
    echo "FAIL: aws_tenant_provision should reject invalid tenant"
    FAIL=$((FAIL+1))
  else
    echo "PASS: aws_tenant_provision rejects invalid tenant"
    PASS=$((PASS+1))
  fi
}

test_gcp_cost_dry_run() {
  # missing --table must fail; with --table dry-run prints the query
  if bash scripts/gcp_cost_by_tenant.sh --dry-run >/dev/null 2>&1; then
    echo "FAIL: gcp_cost_by_tenant should require --table"
    FAIL=$((FAIL+1))
  else
    echo "PASS: gcp_cost_by_tenant requires --table"
    PASS=$((PASS+1))
  fi
  out=$(bash scripts/gcp_cost_by_tenant.sh --table proj.set.tbl --dry-run 2>&1)
  if grep -q "SELECT" <<<"$out" && grep -q "tenant" <<<"$out"; then
    echo "PASS: gcp_cost_by_tenant dry-run prints billing query"
    PASS=$((PASS+1))
  else
    echo "FAIL: gcp_cost_by_tenant dry-run output unexpected"
    FAIL=$((FAIL+1))
  fi
}

test_gke_namespace_dry_run() {
  # missing --tenant must fail; valid tenant dry-run prints manifests
  if bash scripts/gke_tenant_namespace.sh --dry-run >/dev/null 2>&1; then
    echo "FAIL: gke_tenant_namespace should require --tenant"
    FAIL=$((FAIL+1))
  else
    echo "PASS: gke_tenant_namespace requires --tenant"
    PASS=$((PASS+1))
  fi
  out=$(bash scripts/gke_tenant_namespace.sh --tenant acme-corp --dry-run 2>&1)
  if grep -q "ResourceQuota" <<<"$out" && grep -q "NetworkPolicy" <<<"$out"; then
    echo "PASS: gke_tenant_namespace dry-run prints manifests"
    PASS=$((PASS+1))
  else
    echo "FAIL: gke_tenant_namespace dry-run output unexpected"
    echo "$out"
    FAIL=$((FAIL+1))
  fi
}

test_terraform_plan_report_no_args() {
  # missing --dir and no terraform in path should fail cleanly
  if bash scripts/terraform_plan_report.sh >/dev/null 2>&1; then
    echo "FAIL: terraform_plan_report should fail without terraform/dir"
    FAIL=$((FAIL+1))
  else
    echo "PASS: terraform_plan_report fails without terraform"
    PASS=$((PASS+1))
  fi
}

test_k8s_cleanup_validation() {
  # invalid tenant must fail before touching kubectl
  if bash scripts/k8s_tenant_cleanup.sh --tenant "BAD NAME" --dry-run >/dev/null 2>&1; then
    echo "FAIL: k8s_tenant_cleanup should reject invalid tenant"
    FAIL=$((FAIL+1))
  else
    echo "PASS: k8s_tenant_cleanup rejects invalid tenant"
    PASS=$((PASS+1))
  fi
}

test_tag_guard_provider_required() {
  # missing --provider must fail
  if bash scripts/cloud_tag_guard.sh >/dev/null 2>&1; then
    echo "FAIL: cloud_tag_guard should require --provider"
    FAIL=$((FAIL+1))
  else
    echo "PASS: cloud_tag_guard requires --provider"
    PASS=$((PASS+1))
  fi
}

test_region_matrix_dry_run() {
  # dry-run should work without any cloud CLI
  out=$(bash scripts/multi_cloud_region_matrix.sh \
        --provider aws --regions us-east-1,eu-west-1 --cmd 'echo hi' --dry-run 2>&1)
  if grep -q "DRY-RUN" <<<"$out" && grep -q "Done" <<<"$out"; then
    echo "PASS: multi_cloud_region_matrix dry-run iterates regions"
    PASS=$((PASS+1))
  else
    echo "FAIL: multi_cloud_region_matrix dry-run output unexpected"
    echo "$out"
    FAIL=$((FAIL+1))
  fi
  # missing --cmd must fail
  if bash scripts/multi_cloud_region_matrix.sh --provider aws --regions us-east-1 >/dev/null 2>&1; then
    echo "FAIL: multi_cloud_region_matrix should require --cmd"
    FAIL=$((FAIL+1))
  else
    echo "PASS: multi_cloud_region_matrix requires --cmd"
    PASS=$((PASS+1))
  fi
}

test_rotate_creds_provider_required() {
  if bash scripts/rotate_cloud_creds.sh >/dev/null 2>&1; then
    echo "FAIL: rotate_cloud_creds should require --provider"
    FAIL=$((FAIL+1))
  else
    echo "PASS: rotate_cloud_creds requires --provider"
    PASS=$((PASS+1))
  fi
}

test_backup_validation() {
  # missing --source must fail
  if bash scripts/backup_to_s3_gcs.sh --tenant acme >/dev/null 2>&1; then
    echo "FAIL: backup_to_s3_gcs should require --source"
    FAIL=$((FAIL+1))
  else
    echo "PASS: backup_to_s3_gcs requires --source"
    PASS=$((PASS+1))
  fi
  # both buckets missing must fail
  if bash scripts/backup_to_s3_gcs.sh --tenant acme --source /tmp >/dev/null 2>&1; then
    echo "FAIL: backup_to_s3_gcs should require a bucket"
    FAIL=$((FAIL+1))
  else
    echo "PASS: backup_to_s3_gcs requires a bucket"
    PASS=$((PASS+1))
  fi
}

test_docker_prune_dry_run() {
  # Use a stub docker so we don't need a real daemon.
  local stub
  stub=$(mktemp -d)
  cat >"$stub/docker" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "system" && "$2" == "prune" && "$3" == "--help" ]]; then
  echo "  --dry-run          Do not remove anything; print what would be removed"
  exit 0
fi
echo "stub docker: $*"
exit 0
EOF
  chmod +x "$stub/docker"
  out=$(PATH="$stub:$PATH" bash scripts/docker_prune_safe.sh 2>&1)
  if grep -q "Dry-run only" <<<"$out"; then
    echo "PASS: docker_prune_safe defaults to dry-run (no deletion)"
    PASS=$((PASS+1))
  else
    echo "FAIL: docker_prune_safe should default to dry-run"
    echo "$out"
    FAIL=$((FAIL+1))
  fi
  rm -rf "$stub"
}

test_promtool_missing() {
  # promtool absent should fail cleanly (not crash)
  if bash scripts/prometheus_alert_check.sh --files x.yml >/dev/null 2>&1; then
    echo "PASS: prometheus_alert_check with --files and no promtool exits 0? (no) -> "
    FAIL=$((FAIL+1))
  else
    echo "PASS: prometheus_alert_check fails cleanly without promtool"
    PASS=$((PASS+1))
  fi
  # missing both --files and --dir must fail
  if bash scripts/prometheus_alert_check.sh >/dev/null 2>&1; then
    echo "FAIL: prometheus_alert_check should require --files or --dir"
    FAIL=$((FAIL+1))
  else
    echo "PASS: prometheus_alert_check requires --files or --dir"
    PASS=$((PASS+1))
  fi
}

echo "=== DevOps-Utilities test harness ==="
test_rotate_backups
test_terraform_check_no_dir
test_cleanup_logs_dry_run
test_aws_cost_dry_run
test_aws_provision_validation
test_gcp_cost_dry_run
test_gke_namespace_dry_run
test_terraform_plan_report_no_args
test_k8s_cleanup_validation
test_tag_guard_provider_required
test_region_matrix_dry_run
test_rotate_creds_provider_required
test_backup_validation
test_docker_prune_dry_run
test_promtool_missing

echo
echo "Results: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]] || exit 1
