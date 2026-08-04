# Atlas Commerce - GitHub Actions OIDC + Human Approval Gate

Creates the IAM identities GitHub Actions uses to run Terraform against AWS, with no long-lived access keys.

Resources:

- GitHub OIDC provider (one per account)
- `gh-actions-atlas-commerce-terraform-plan` — read-only, assumable from any ref (PRs and branches). Runs `terraform plan` in CI without needing approval.
- One `gh-actions-atlas-commerce-terraform-apply-<env>` role per entry in `var.environments` — assumable only from `master`, and denied all write actions until a human operator approves it (see below).

## The human approval gate

When `require_deploy_approval = true` for an environment (default), that apply role is denied all mutating AWS calls unless it carries the `deploy-approved = true` tag. GitHub Actions has no permission to set that tag. Only a human operator with IAM tagging rights on this account can.

**Alpha currently sets `require_deploy_approval = false`** so Live Alpha apply can write without `approve-deploy.sh` while the stack is brought up. Re-enable the flag and re-apply this module once alpha is functional.

For gated envs, an `apply` job can start and authenticate, but every create/update/delete call fails with `AccessDenied` until you explicitly approve that run.

### Approving a deploy

```bash
cd platform/terraform/bootstrap/gh-actions-oidc
./scripts/approve-deploy.sh alpha
```

Then approve the pending job in the GitHub Environment. The tag does **not** auto-expire — revoke it yourself once the run finishes:

```bash
./scripts/revoke-deploy.sh alpha
```

Check what's currently open at any time:

```bash
./scripts/status-deploy.sh
```

### Why this and not just a GitHub Environment approval

A GitHub Environment approval is a gate inside GitHub — if the repo, the OIDC trust, or the Actions runner is ever compromised, that gate doesn't help. This gate lives in AWS IAM: even a fully compromised GitHub Actions run cannot write anything to this account unless a human, from their own AWS session, tagged the role first. Every tag/untag call is a human-attributable action in CloudTrail.

## Usage

```bash
cd platform/terraform/bootstrap/gh-actions-oidc

cp terraform.tfvars.example terraform.tfvars
# Fill owner_id / repo_id per repo (immutable OIDC sub claims):
#   gh api repos/OWNER/REPO --jq '{owner_id:.owner.id,repo_id:.id}'

# Generate backend.hcl from the aws-backend bootstrap's own state:
cd ../aws-backend && ./generate-backend-hcl.sh bootstrap/gh-actions-oidc && cd -

terraform init -backend-config=backend.hcl
terraform fmt
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

Trust accepts both GitHub OIDC `sub` formats (legacy `repo:OWNER/REPO:...` and
immutable `repo:OWNER@OWNER_ID/REPO@REPO_ID:...`). Without the numeric IDs,
repos on the immutable format get `AccessDenied` on `AssumeRoleWithWebIdentity`.

After applying, feed `apply_role_arns` and `plan_role_arn` into the repo's GitHub Actions secrets/variables — see `.github/workflows/README.md`.
