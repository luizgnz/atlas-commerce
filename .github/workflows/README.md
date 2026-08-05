# GitHub Actions Workflows

**All entrypoint pipelines are manual-only** (`workflow_dispatch`). Nothing runs on `push` or `pull_request`. Reusable workflows (`reusable-*.yml`) stay `workflow_call`-only and are invoked by entrypoints.

GitHub registers `workflow_dispatch` from the **default branch** (`master`). Once a workflow file is on `master`, you can run it from **any branch**:

```bash
gh workflow run <workflow-file.yml> --ref <branch>
```

Or: Actions → pick the workflow → **Run workflow** (choose the branch).

---

## Service CI (`*-service-ci.yml`)

Each service has an entrypoint that calls [`reusable-service-ci.yml`](reusable-service-ci.yml) (build, test, scan, optional ECR push). Trigger: **manual only**.

| Workflow | Service path |
|---|---|
| `auth-service-ci.yml` | `services/auth-service` |
| `catalog-service-ci.yml` | `services/catalog-service` |
| `cart-service-ci.yml` | `services/cart-service` |
| `pricing-service-ci.yml` | `services/pricing-service` |
| `coupon-service-ci.yml` | `services/coupon-service` |
| `inventory-service-ci.yml` | `services/inventory-service` |
| `payment-service-ci.yml` | `services/payment-service` |
| `order-service-ci.yml` | `services/order-service` |
| `shipping-service-ci.yml` | `services/shipping-service` |
| `notification-service-ci.yml` | `services/notification-service` |
| `audit-service-ci.yml` | `services/audit-service` |
| `gateway-service-ci.yml` | `services/gateway-service` |

Example:

```bash
gh workflow run auth-service-ci.yml --ref master
```

---

## Deploy Services (selective build → ECR → Helm)

Manual workflow: [`.github/workflows/deploy-services.yml`](deploy-services.yml).

```bash
gh workflow run deploy-services.yml --ref <branch>
```

The run uses the selected ref’s code (workflows + services). Both the ECR build/push job (via `reusable-service-ci`) and the Helm deploy job use GitHub Environment `alpha` (OIDC claim `…:environment:alpha`). IAM for ECR push and EKS deploy trusts both `ref:refs/heads/*` and `environment:alpha`. Per-service CI wrappers inherit the same Environment through the reusable job (default `github-environment: alpha`).

1. Actions → **Deploy Services** → **Run workflow** (pick the branch), or `gh workflow run` as above.
2. All twelve services are selected by default. Uncheck any you do **not** want to rebuild and roll out.
3. Unchecking a service skips its build/push/rollout only — it does **not** uninstall or disable that workload in the cluster.
4. The run builds from the branch/tag you selected, pushes `sha-<commit>-<run_id>-<attempt>` tags to ECR, then `helm upgrade`s release `atlas` in namespace `atlas` on EKS alpha (image overrides for the selected services only).

### Environment `alpha` Variables required

Set these under **Settings → Environments → alpha → Environment variables** (not repository Variables). ARNs and IDs are fine as Variables; Secrets are only needed if you choose to store sensitive values that way.

| Variable | Value |
|---|---|
| `AWS_REGION` | `eu-central-1` |
| `AWS_ACCOUNT_ID` | AWS account ID |
| `AWS_ECR_PUSH_ROLE_ARN` | output `github_actions_ecr_push_role_arn` from `01-aws` |
| `ECR_REPOSITORY_PREFIX` | `atlas-commerce` |
| `AWS_EKS_DEPLOY_ROLE_ARN` | output `github_actions_eks_deploy_role_arn` from `01-aws` |
| `EKS_CLUSTER_NAME` | `atlas-commerce-alpha` (output `eks_cluster_name` from `01-aws`) |
| `EXTERNAL_SECRETS_ROLE_ARN` | optional; output `external_secrets_role_arn` from `01-aws`. If unset, defaults to `arn:aws:iam::<account>:role/atlas-commerce-alpha-external-secrets-role` |

Before Helm, Deploy Services checks for External Secrets CRDs and **installs the operator** (Helm chart `external-secrets`) if they are missing.

Apply `01-aws` after pulling the EKS deploy role / IAM OIDC trust updates so those outputs exist and `environment:alpha` is trusted, then set the Environment variables above.

There is **no** approval gate on deploy in v1 (Environment `alpha` has no required reviewers for this path).

---

# Terraform GitHub Actions Workflows

Source of truth lives next to the Terraform roots (symlinked into this folder):

- `platform/terraform/bootstrap/pipelines/`
- `platform/terraform/01-aws/pipelines/`

OIDC / IAM: see `platform/terraform/bootstrap/README.md`. All Terraform entrypoints are **manual only** (`workflow_dispatch`).

## Workflows

| File (symlink) | Root | Apply? |
|---|---|---|
| `terraform-bootstrap.yml` | `bootstrap/` | No — plan/validate only (local state) |
| `terraform-apply.yml` | `01-aws/` | Yes — input `environment` (default `alpha`) |
| `terraform-destroy.yml` | `01-aws/` | Yes — confirm `destroy-<env>` + Environment `<env>-destroy` |
| `reusable-terraform.yml` | shared | `workflow_call` only |

```bash
gh workflow run terraform-apply.yml --ref <branch> -f environment=alpha
gh workflow run terraform-destroy.yml --ref master -f environment=alpha -f confirm=destroy-alpha
```

`alpha` keep GitHub Environment reviewers empty and `require_deploy_approval = false` in bootstrap until the stack is functional.

## One-time setup

1. Apply `platform/terraform/bootstrap` by hand (see its README).
2. `./scripts/generate-backend-hcl.sh alpha` from bootstrap.
3. Keep `platform/terraform/environments.yml` up to date.
4. Create GitHub Environments (`alpha`, later `staging`/`prod`) and set Deploy Services variables from `01-aws` outputs.

## Approving a gated deploy

When `require_deploy_approval = true`:

```bash
cd platform/terraform/bootstrap
./scripts/approve-deploy.sh <env>
# … run apply …
./scripts/revoke-deploy.sh <env>
./scripts/status-deploy.sh
```
