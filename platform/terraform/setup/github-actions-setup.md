# GitHub Actions Setup — Atlas Commerce Terraform

Manual, one-time steps to finish wiring GitHub Actions to AWS after applying
`platform/terraform/bootstrap` (unified root: state bucket + GitHub OIDC).
Re-apply bootstrap if the account was wiped; then refresh
[`environments.yml`](../environments.yml) from its outputs.

## 1. Environment config

There are no repository variables to set. All per-environment values (AWS
region/account ID, state bucket, IAM role ARNs) live in
[`platform/terraform/environments.yml`](../environments.yml) — the
`reusable-terraform.yml` workflow reads that file at run time via its
`config` job. `environments.yml` already has entries for `alpha` and
`bootstrap`; re-run `terraform output` in the relevant bootstrap module and
update that file if any of these values ever change (e.g. after rotating a
role or recreating the state bucket).

Add `staging`/`prod` by adding a new top-level key to `environments.yml`
plus a matching key in `bootstrap/variables.tf`'s
`environments` map (and applying that module again) — no workflow file
needs to change.

## 2. GitHub Environments

`Settings → Environments` — create one environment per deployable Terraform
live environment, used only for the manual-approval gate (required
reviewers), not for variables. `alpha` is currently the only one — there is
no separate `shared` environment; ECR repositories and their GitHub Actions
push role live inside `alpha` too.

### `alpha`
- Required reviewers: **leave empty** until the stack is functional (reviewers
  pause every job that uses `environment: alpha`, including Deploy Services).
  Code cannot clear reviewers — remove them in Settings → Environments → alpha
  if any are configured.
- No environment variables needed — `TERRAFORM_APPLY_ROLE_ARN` comes from
  `environments.yml` via the `config` job.
- Deployment branches: no restriction — `alpha` is a disposable test
  environment, its AWS-side trust policy already allows any branch
  (`require-master: false` in `terraform-live-alpha.yml`).
- AWS IAM deny-until-approved gate is off for alpha
  (`require_deploy_approval = false` in `bootstrap`).

Add `staging`/`prod` the same way once those environments have real `.tf`
files and their own entry in `environments.yml` (with approvals enabled).

## 3. Verify

Dispatch **Terraform - Live Alpha** from Actions (or
`gh workflow run terraform-live-alpha.yml --ref master`) and confirm plan +
apply both run without waiting for a reviewer. After re-enabling gates, apply
will pause on Environment reviewers and/or need `approve-deploy.sh`.

## 4. Rotate the exposed credential

The Access Key ID `AKIAYBVLUSDFTU2ZQ74Z` (old AWS account) was pasted into
this chat during troubleshooting and should be deactivated/deleted from
that account's IAM console if it hasn't been already — it was exposed in
plaintext outside of AWS.
