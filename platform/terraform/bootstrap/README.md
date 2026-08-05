# Bootstrap — account foundation

Single Terraform root that prepares the AWS account **before** the product
stack in [`../01-aws`](../01-aws) can run.

## What it creates

| File | Resources |
|------|-----------|
| `01-state-backend.tf` | S3 bucket for remote Terraform state (versioned, encrypted, private) |
| `02-github-oidc.tf` | GitHub OIDC provider, read-only **plan** role, per-env **apply** roles |

One root → one set of `00-versions` / `00-providers` / `00-variables` → one apply.

This directory uses **local state** on purpose: it creates the remote backend
that `01-aws` consumes. Do not point this root at the product state key.

## Order

1. Apply this bootstrap (once per account, rarely thereafter).
2. Generate the product backend file:
   ```bash
   ./scripts/generate-backend-hcl.sh alpha
   ```
3. Apply [`../01-aws`](../01-aws) with `envs/alpha.tfvars`.

## Scripts (all bootstrap-owned)

| Script | Purpose |
|--------|---------|
| `scripts/generate-backend-hcl.sh <env>` | Writes `../01-aws/envs/<env>.backend.hcl` from outputs |
| `scripts/approve-deploy.sh <env>` | Tags `gh-actions-…-terraform-apply-<env>` with `deploy-approved=true` |
| `scripts/revoke-deploy.sh <env>` | Removes that tag |
| `scripts/status-deploy.sh` | Shows which apply roles currently have the gate open |

`approve` / `revoke` / `status` mutate **IAM roles created here**, not resources
inside `01-aws`. You run them when applying any gated environment (including
`bootstrap` or `alpha`). Alpha currently has `require_deploy_approval = false`
so the gate is off until you re-enable it in `variables.tf` / tfvars.

## Local usage

```bash
cd platform/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # edit if needed
terraform init
terraform plan
terraform apply

./scripts/generate-backend-hcl.sh alpha
```

Keep `terraform.tfvars` and `*.tfstate` out of git (see `../.gitignore`).

## Pipelines

Workflows live in [`pipelines/`](pipelines/). GitHub Actions entrypoints under
`.github/workflows/` symlink here. Bootstrap CI is plan/validate only —
apply stays manual.
