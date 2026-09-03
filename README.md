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

| Script | What it does |
|--------|--------------|
| `scripts/rotate_backups.sh` | Keeps only the N most recent backups in a directory. |
| `scripts/cleanup_logs.sh` | Deletes old / oversized log files (dry-run supported). |
| `scripts/terraform_check.sh` | Pre-apply sanity: `fmt`, `init`, `validate`, optional `plan`. |
| `scripts/deploy.sh` | Zero-downtime deploy helper with health-check & rollback hook. |
| `lambda/cloudfront-remove-html-extension.js` | Lambda@Edge that appends `.html` to CloudFront requests. |

## Quick start

```bash
# Rotate backups, keeping the 7 newest
./scripts/rotate_backups.sh /data/backups 7

# Preview which old logs would be deleted
./scripts/cleanup_logs.sh /var/log --older-than 30 --dry-run

# Validate a Terraform directory
./scripts/terraform_check.sh --dir ./terraform/prod --plan
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
