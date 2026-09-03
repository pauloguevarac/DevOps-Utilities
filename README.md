# DevOps Utilities

A curated collection of DevOps scripts, snippets, and CI/CD helpers I use
across production infrastructure. Clean, documented, and battle-tested.

## Structure

```
.
├── lambda/          # Serverless / Lambda@Edge functions
├── scripts/         # Standalone DevOps automation scripts
├── terraform/       # (optional) Terraform modules / configs
├── .github/workflows/  # Reusable CI/CD workflows
├── run_tests.sh     # Lightweight test harness
└── LICENSE
```

## Scripts

### Core utilities

| Script | What it does |
|--------|--------------|
| `scripts/rotate_backups.sh` | Keeps only the N most recent backups in a directory. |
| `scripts/cleanup_logs.sh` | Deletes old / oversized log files (dry-run supported). |
| `scripts/terraform_check.sh` | Pre-apply sanity: `fmt`, `init`, `validate`, optional `plan`. |
| `scripts/deploy.sh` | Zero-downtime deploy helper with health-check & rollback hook. |
| `lambda/cloudfront-remove-html-extension.js` | Lambda@Edge that appends `.html` to CloudFront requests. |

### Cloud multi-tenant (AWS & GCP)

| Script | What it does |
|--------|--------------|
| `scripts/aws_cost_by_tenant.sh` | AWS costs grouped by a cost-allocation tag (e.g. `Tenant`) via Cost Explorer. |
| `scripts/aws_tenant_provision.sh` | Provisions an isolated S3 bucket + tenant-scoped IAM policy, all tagged. Idempotent. |
| `scripts/gcp_cost_by_tenant.sh` | GCP costs grouped by a `tenant` label from the BigQuery billing export. |
| `scripts/gke_tenant_namespace.sh` | Creates an isolated GKE namespace with quota, limitrange & network policy. |
| `scripts/k8s_tenant_cleanup.sh` | **Safely** removes a tenant namespace (requires explicit confirmation). |
| `scripts/cloud_tag_guard.sh` | Verifies resources carry required tags/labels (so cost grouping actually works). |
| `scripts/backup_to_s3_gcs.sh` | Backs up a directory to S3 (versioned) and/or GCS, tenant-prefixed. |
| `scripts/multi_cloud_region_matrix.sh` | Runs a command across a provider × region matrix (DR / consistency). |

### Operations & security

| Script | What it does |
|--------|--------------|
| `scripts/terraform_plan_report.sh` | Summarizes `terraform plan` counts into a PR-friendly report. |
| `scripts/rotate_cloud_creds.sh` | Lists stale cloud access keys / service-account keys (read-only by default). |
| `scripts/docker_prune_safe.sh` | Dry-run preview of `docker system prune` before actually deleting. |
| `scripts/prometheus_alert_check.sh` | Validates Prometheus rule files with `promtool` before applying. |

All scripts default to a **dry-run / no-op** unless you explicitly opt in,
and validate inputs (tenant names, args) to stay safe for automation.

## Quick start

```bash
# Rotate backups, keeping the 7 newest
./scripts/rotate_backups.sh /data/backups 7

# Preview which old logs would be deleted
./scripts/cleanup_logs.sh /var/log --older-than 30 --dry-run

# Validate a Terraform directory
./scripts/terraform_check.sh --dir ./terraform/prod --plan

# AWS: cost by tenant tag (preview first)
./scripts/aws_cost_by_tenant.sh --tag Tenant --dry-run

# AWS: provision an isolated tenant bucket + policy
./scripts/aws_tenant_provision.sh --tenant acme-corp --dry-run

# GCP: cost by tenant label
./scripts/gcp_cost_by_tenant.sh --table proj.billing.export_1 --dry-run

# GKE: isolated tenant namespace
./scripts/gke_tenant_namespace.sh --tenant acme-corp --dry-run

# Terraform plan summary (PR-friendly)
./scripts/terraform_plan_report.sh --dir terraform/prod --format md

# Find cloud access keys older than 90 days (read-only)
./scripts/rotate_cloud_creds.sh --provider aws --max-age 90

# Preview Docker prune before deleting
./scripts/docker_prune_safe.sh --all
```

## CI/CD

The included [GitHub Actions workflow](.github/workflows/ci.yml) runs
shellcheck, Terraform validation, and the test harness on every push/PR.

## Tests

```bash
./run_tests.sh
```

## License

[MIT](LICENSE)