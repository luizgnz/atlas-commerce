# GitHub Actions Setup — Atlas Commerce Terraform

Manual, one-time steps to finish wiring GitHub Actions to AWS after applying
`bootstrap/aws-backend` and `bootstrap/gh-actions-oidc`. Both bootstrap
modules are already applied against AWS account `553337000139`
(`eu-central-1`).

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
plus a matching key in `bootstrap/gh-actions-oidc/variables.tf`'s
`environments` map (and applying that module again) — no workflow file
needs to change.

## 2. GitHub Environments

`Settings → Environments` — create one environment per deployable Terraform
live environment, used only for the manual-approval gate (required
reviewers), not for variables. `alpha` is currently the only one — there is
no separate `shared` environment; ECR repositories and their GitHub Actions
push role live inside `alpha` too.

### `alpha`
- Required reviewers: add at least one human reviewer.
- No environment variables needed — `TERRAFORM_APPLY_ROLE_ARN` comes from
  `environments.yml` via the `config` job.
- Deployment branches: no restriction — `alpha` is a disposable test
  environment, its AWS-side trust policy already allows any branch
  (`require-master: false` in `terraform-live-alpha.yml`).

Add `staging`/`prod` the same way once those environments have real `.tf`
files and their own entry in `environments.yml`.

## 3. Verify

Open a PR that touches `platform/terraform/live/aws/alpha/**` and confirm
the `plan` job runs and comments the Terraform plan on the PR. Then merge
(or push to any branch, for `alpha`) and confirm the `apply` job pauses for
environment approval.

To actually let `apply` write to AWS, a human must also open the AWS-side
gate — see `bootstrap/gh-actions-oidc/README.md` (`scripts/approve-deploy.sh` /
`scripts/revoke-deploy.sh`).

## 4. Rotate the exposed credential

The Access Key ID `AKIAYBVLUSDFTU2ZQ74Z` (old AWS account) was pasted into
this chat during troubleshooting and should be deactivated/deleted from
that account's IAM console if it hasn't been already — it was exposed in
plaintext outside of AWS.
