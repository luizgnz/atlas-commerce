# Atlas Commerce Terraform

```text
platform/terraform/
├── environments.yml     # CI registry (account, roles, state bucket)
├── bootstrap/           # Account foundation (state bucket + GitHub OIDC)
└── 01-aws/              # Product stack (flat, numbered by create order)
```

## Principles

- Terraform provisions cloud infrastructure; Helm deploys applications.
- **One product root** (`01-aws`) + `envs/<name>.tfvars` per environment.
- Isolated state keys (`atlas-commerce/<env>/terraform.tfstate`). No workspaces.
- Bootstrap is a separate root with local state; apply it once before `01-aws`.
- Secrets and generated `*.backend.hcl` / `terraform.tfvars` are not committed.

## Order of life

1. `bootstrap/` — create state bucket + OIDC/IAM roles  
2. `bootstrap/scripts/generate-backend-hcl.sh alpha`  
3. `01-aws/` — `plan/apply -var-file=envs/alpha.tfvars`

## Docs

- [`bootstrap/README.md`](bootstrap/README.md)
- [`01-aws/README.md`](01-aws/README.md)
