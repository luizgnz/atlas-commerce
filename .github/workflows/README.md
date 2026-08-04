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
| `AWS_ECR_PUSH_ROLE_ARN` | output `github_actions_ecr_push_role_arn` from `live/aws/alpha` |
| `ECR_REPOSITORY_PREFIX` | `atlas-commerce` |
| `AWS_EKS_DEPLOY_ROLE_ARN` | output `github_actions_eks_deploy_role_arn` from `live/aws/alpha` |
| `EKS_CLUSTER_NAME` | `atlas-commerce-alpha` (output `eks_cluster_name` from `live/aws/alpha`) |
| `EXTERNAL_SECRETS_ROLE_ARN` | optional; output `external_secrets_role_arn` from `live/aws/alpha`. If unset, defaults to `arn:aws:iam::<account>:role/atlas-commerce-alpha-external-secrets-role` |

Before Helm, Deploy Services checks for External Secrets CRDs and **installs the operator** (Helm chart `external-secrets`) if they are missing.

Apply `live/aws/alpha` after pulling the EKS deploy role / IAM OIDC trust updates so those outputs exist and `environment:alpha` is trusted, then set the Environment variables above.

There is **no** approval gate on deploy in v1 (Environment `alpha` has no required reviewers for this path).

---

# Terraform GitHub Actions Workflows

Deploys `platform/terraform/live/aws/*` with OIDC — no long-lived AWS credentials in GitHub. See `platform/terraform/bootstrap/gh-actions-oidc/README.md` for the IAM side.

All Terraform entrypoints are **manual only** (`workflow_dispatch`), including bootstrap plan/validate workflows.

## Destroy Alpha (manual only)

Manual workflow: [`.github/workflows/terraform-destroy-alpha.yml`](terraform-destroy-alpha.yml).

Runs `terraform destroy` on `live/aws/alpha`. Requires:

1. `confirm=destroy-alpha` on `workflow_dispatch`
2. **GitHub Environment `alpha-destroy`** with required reviewers (approval gate). Deploy/apply keep using Environment `alpha` without reviewers.

After approval, destroy assumes the Terraform apply IAM role via Environment `alpha` (OIDC). Irreversible for that environment’s AWS resources (EKS, RDS, Redis, ECR repos, etc.).

```bash
gh workflow run terraform-destroy-alpha.yml --ref master -f confirm=destroy-alpha
# then approve the pending deployment for Environment alpha-destroy in the GitHub UI
```

## Live Alpha (manual only)

Manual workflow: [`.github/workflows/terraform-live-alpha.yml`](terraform-live-alpha.yml).

Optional input **`deploy_services`** (default **false**): after a successful Terraform apply, also runs [Deploy Services](deploy-services.yml) for all services. Leave unchecked for infra-only.

1. Actions → **Terraform - Live Alpha** → **Run workflow** (pick the branch), or:

```bash
gh workflow run terraform-live-alpha.yml --ref <branch>
```

The run uses the selected ref’s code. Plan + apply go through `reusable-terraform.yml` and GitHub Environment `alpha` (kept for OIDC `…:environment:alpha`). **Until alpha is functional, leave Environment `alpha` with no required reviewers** (Settings → Environments → alpha) and keep the AWS `deploy-approved` gate off for alpha (`require_deploy_approval = false` in `bootstrap/gh-actions-oidc`).

## Workflows

| File | Module | Apply? | Trigger |
|---|---|---|---|
| `terraform-bootstrap-aws-backend.yml` | `bootstrap/aws-backend` | No — applied by hand, uses local state | Manual only (`workflow_dispatch`) |
| `terraform-bootstrap-gh-actions-oidc.yml` | `bootstrap/gh-actions-oidc` | No — applied by hand, security-sensitive | Manual only (`workflow_dispatch`) |
| `terraform-live-alpha.yml` | `live/aws/alpha` | Yes (ungated while stacking up), any branch | Manual only (`workflow_dispatch`) |

All three call the shared `reusable-terraform.yml`. `alpha` is currently the only live environment — it holds everything, including resources that would otherwise be split into a separate "shared" environment (e.g. the ECR repositories and their GitHub Actions push role). Add a `staging`/`prod` workflow the same way once those environments have real `.tf` files.

`alpha` is a disposable test environment: its apply job uses the GitHub Environment `alpha` (OIDC `sub` …`:environment:alpha`) and `require-master: false`, so apply can run from any branch when you dispatch the workflow. Approvals are temporarily off for alpha (no Environment reviewers; IAM deny gate disabled via `require_deploy_approval = false`). Re-enable both once the stack is functional. Any future `staging`/`prod` should keep approvals and a `master`-only restriction.

## One-time setup

1. Apply `bootstrap/aws-backend` by hand (already done — see its README).
2. Apply `bootstrap/gh-actions-oidc` by hand (see its README) to create the OIDC provider and the `plan`/`apply-<env>` IAM roles.
3. Keep `platform/terraform/environments.yml` up to date — Terraform plan/apply reads AWS account/region, state bucket, and plan/apply role ARNs from that file (not from GitHub repository Variables).
4. Create a **GitHub Environment** per deployable Terraform env (`alpha`, and later `staging`/`prod`) under `Settings → Environments`:
   - **alpha (temporary):** leave **required reviewers empty** so `workflow_dispatch` apply does not pause. Code cannot clear reviewers — do it in the GitHub UI if any are set.
   - Later / staging/prod: add required reviewers when you want a human sign-off.
   - Terraform apply uses the Environment for the OIDC `…:environment:<name>` claim; role ARNs still come from `environments.yml` via the reusable workflow `config` job.
   - For service CI / Deploy Services (ECR push + Helm), set the Environment Variables listed in [Environment `alpha` Variables required](#environment-alpha-variables-required) above.

## Approving a real deploy (staging/prod, or alpha after re-enabling gates)

When `require_deploy_approval = true` for an env, the apply IAM role denies every write until a human tags it. Open/close the AWS-side gate:

```bash
cd platform/terraform/bootstrap/gh-actions-oidc
./scripts/approve-deploy.sh <env>    # opens the AWS-side gate
# … run / approve the apply job …
./scripts/revoke-deploy.sh <env>     # closes the AWS-side gate again
```

`./scripts/status-deploy.sh` shows which environments are currently open. **Alpha currently has this gate disabled in Terraform** (`require_deploy_approval = false`); re-apply `bootstrap/gh-actions-oidc` after flipping that flag to restore the deny policy. Until you re-apply, leaving `deploy-approved=true` on the alpha apply role also keeps writes allowed.

## Why plan never needs approval

The `plan` role only has `ReadOnlyAccess` and is assumable from any ref of this repo (scoped to `repo:Nitros64/atlas-commerce:*`). It cannot create, modify, or delete anything. Bootstrap and Live Alpha plan/apply only run when you dispatch the workflow.
