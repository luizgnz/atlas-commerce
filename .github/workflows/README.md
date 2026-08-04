# GitHub Actions Workflows

## Deploy Services (selective build → ECR → Helm)

Manual workflow: [`.github/workflows/deploy-services.yml`](deploy-services.yml).

GitHub only registers `workflow_dispatch` from the **default branch** (`master`). Once `deploy-services.yml` is on `master`, you can run it from **any branch**:

```bash
gh workflow run deploy-services.yml --ref <branch>
```

The run uses the selected ref’s code (workflows + services). The Helm job uses GitHub Environment `alpha` (same OIDC claim as Terraform live alpha: `…:environment:alpha`). IAM for ECR push and EKS deploy trusts both `ref:refs/heads/*` and `environment:alpha`.

1. Actions → **Deploy Services** → **Run workflow** (pick the branch), or `gh workflow run` as above.
2. All twelve services are selected by default. Uncheck any you do **not** want to rebuild and roll out.
3. Unchecking a service skips its build/push/rollout only — it does **not** uninstall or disable that workload in the cluster.
4. The run builds from the branch/tag you selected, pushes `sha-<commit>-<run_id>-<attempt>` tags to ECR, then `helm upgrade`s release `atlas` in namespace `atlas` on EKS alpha (image overrides for the selected services only).

### Repository variables required

| Variable | Value |
|---|---|
| `AWS_REGION` | e.g. `eu-central-1` |
| `AWS_ACCOUNT_ID` | AWS account ID |
| `AWS_ECR_PUSH_ROLE_ARN` | output `github_actions_ecr_push_role_arn` from `live/aws/alpha` |
| `ECR_REPOSITORY_PREFIX` | e.g. `atlas-commerce` |
| `AWS_EKS_DEPLOY_ROLE_ARN` | output `github_actions_eks_deploy_role_arn` from `live/aws/alpha` |
| `EKS_CLUSTER_NAME` | output `eks_cluster_name` from `live/aws/alpha` (default `atlas-commerce-alpha`) |

Apply `live/aws/alpha` after pulling the EKS deploy role / IAM OIDC trust updates so those outputs exist and `environment:alpha` is trusted, then set the variables above.

There is **no** approval gate on deploy in v1 (Environment `alpha` has no required reviewers for this path).

---

# Terraform GitHub Actions Workflows

Deploys `platform/terraform/live/aws/*` via `plan` on every PR and a gated `apply` on push, using OIDC — no long-lived AWS credentials in GitHub. See `platform/terraform/bootstrap/gh-actions-oidc/README.md` for the IAM side.

## Workflows

| File | Module | Apply? |
|---|---|---|
| `terraform-bootstrap-aws-backend.yml` | `bootstrap/aws-backend` | No — applied by hand, uses local state |
| `terraform-bootstrap-gh-actions-oidc.yml` | `bootstrap/gh-actions-oidc` | No — applied by hand, security-sensitive |
| `terraform-live-alpha.yml` | `live/aws/alpha` | Yes, gated, any branch |

All three call the shared `reusable-terraform.yml`. `alpha` is currently the only live environment — it holds everything, including resources that would otherwise be split into a separate "shared" environment (e.g. the ECR repositories and their GitHub Actions push role). Add a `staging`/`prod` workflow the same way once those environments have real `.tf` files.

`alpha` is a disposable test environment: its apply job uses the GitHub Environment `alpha` (OIDC `sub` …`:environment:alpha`, see `allowed_sub` in `bootstrap/gh-actions-oidc/variables.tf`) and `require-master: false`, so apply can run from any branch. The two approval gates below still apply regardless of branch. Any future `staging`/`prod` should keep a `master`-only restriction at the workflow and/or Environment level.

## One-time setup

1. Apply `bootstrap/aws-backend` by hand (already done — see its README).
2. Apply `bootstrap/gh-actions-oidc` by hand (see its README) to create the OIDC provider and the `plan`/`apply-<env>` IAM roles.
3. In the GitHub repo settings, set these **repository variables** (`Settings → Secrets and variables → Actions → Variables`):

   | Variable | Value |
   |---|---|
   | `AWS_REGION` | `eu-central-1` |
   | `AWS_ACCOUNT_ID` | `553337000139` |
   | `TERRAFORM_STATE_BUCKET` | output `terraform_state_bucket_name` from `bootstrap/aws-backend` |
   | `TERRAFORM_PLAN_ROLE_ARN` | output `plan_role_arn` from `bootstrap/gh-actions-oidc` |

4. Create a **GitHub Environment** per deployable Terraform env (`alpha`, and later `staging`/`prod`) under `Settings → Environments`:
   - Add **required reviewers** — this is the GitHub-side approval gate (pauses the `apply` job for your sign-off).
   - Add an environment-scoped variable `TERRAFORM_APPLY_ROLE_ARN` with that environment's ARN from `apply_role_arns` in the `bootstrap/gh-actions-oidc` output.

## Approving a real deploy

A GitHub Environment approval alone is not enough — the apply IAM role denies every write call in AWS until a human separately tags it. Two independent gates, one in GitHub, one in AWS:

```bash
cd platform/terraform/bootstrap/gh-actions-oidc
./scripts/approve-deploy.sh alpha    # opens the AWS-side gate for alpha
```

Then approve the pending `apply` job in the GitHub UI. Once the run finishes:

```bash
./scripts/revoke-deploy.sh alpha     # closes the AWS-side gate again
```

`./scripts/status-deploy.sh` shows which environments are currently open.

## Why plan never needs approval

The `plan` role only has `ReadOnlyAccess` and is assumable from any ref of this repo (scoped to `repo:Nitros64/atlas-commerce:*`). It cannot create, modify, or delete anything, so it runs unattended on every PR to give reviewers a real plan diff in the PR comments.
