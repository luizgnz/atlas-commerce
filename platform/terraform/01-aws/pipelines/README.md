# 01-aws pipelines

Source of truth for product-stack GitHub Actions workflows.

| File | Purpose |
|------|---------|
| `reusable-terraform.yml` | Shared plan/apply (OIDC + environments.yml) |
| `terraform-apply.yml` | Manual apply for `envs/<environment>.tfvars` (default alpha) |
| `terraform-destroy.yml` | Gated manual destroy |

Entrypoints under `.github/workflows/` are symlinks to these files so GitHub
Actions can discover them.
