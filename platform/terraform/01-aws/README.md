# Atlas Commerce - 01-aws Product Stack

Flat Terraform root module for the Atlas Commerce AWS product stack, deployed
to AWS Frankfurt (`eu-central-1`). This replaces the old
`modules/aws/*` + `live/aws/alpha` module composition: every resource that
used to live behind a `module "..."` block is now declared directly in this
directory. There are no `module` blocks in `01-aws/`.

## Why flat?

The old structure spread every resource across a reusable module (e.g.
`modules/aws/network`) and a thin per-environment composition
(`live/aws/alpha`) that wired modules together. Since alpha is (for now) the
only environment this project runs, the extra indirection cost more to
navigate than it saved. `01-aws` inlines all of it into one product root,
numbered by creation/dependency order.

## File layout

| File | Contents |
|------|----------|
| `00-versions.tf` | `required_version` / `required_providers` (aws, http, tls) |
| `00-providers.tf` | AWS provider block + default tags |
| `00-backend.tf` | Partial S3 backend (`backend "s3" {}`) |
| `00-variables.tf` | Every input variable, merged from all former modules |
| `00-locals.tf` | Shared locals: `name_prefix`, `common_tags` |
| `01-network.tf` | VPC, subnets, route tables, IGW, NAT Gateway |
| `02-security-groups.tf` | ALB / EKS nodes / RDS / Redis security groups + ALB ingress rules |
| `03-eks.tf` | EKS cluster, managed node group, cluster/node IAM roles, IRSA (OIDC provider, VPC CNI, EBS CSI, AWS Load Balancer Controller, External Secrets, Velero), add-ons |
| `04-rds.tf` | RDS PostgreSQL instance, DB subnet group, EKS→RDS ingress rule |
| `05-redis.tf` | ElastiCache Redis replication group, subnet group, EKS→Redis ingress rule |
| `06-ecr.tf` | ECR repositories + lifecycle policies |
| `07-secrets.tf` | Secrets Manager secret containers |
| `08-velero.tf` | Velero S3 backup bucket (versioned, encrypted, private) |
| `09-iam-github.tf` | GitHub Actions OIDC IAM roles (ECR push, EKS deploy) |
| `10-eks-github-access.tf` | EKS access entry/policy association granting the GitHub Actions deploy role cluster-admin |
| `99-outputs.tf` | All outputs, resolved to direct resource references |
| `envs/alpha.tfvars` | Non-secret input values for the alpha environment |
| `envs/alpha.backend.hcl.example` | Template for the (gitignored) generated `alpha.backend.hcl` |
| `.terraform.lock.hcl` | Provider version lock, carried over from `live/aws/alpha` |

Numbering `00`-`10` reflects the order resources are actually created in:
network → security groups → EKS (needs the VPC/subnets) → RDS/Redis (need
the EKS cluster security group for ingress rules) → ECR/Secrets/Velero
(mostly independent) → GitHub Actions IAM (needs ECR repo ARNs + EKS cluster
ARN) → EKS access wiring (needs both the cluster and the deploy role).
Terraform resolves the actual dependency graph from resource references
regardless of file order — the numbers are a reading aid, not a build order.

## Fixed-value toggles

Several module inputs were always passed as hardcoded literals by
`live/aws/alpha` (never driven by a variable), e.g. `enable_irsa = true`,
`enable_velero_irsa = true`, `cluster_endpoint_private_access = true`,
`node_group_name = "default"`. These are now `local` values declared next to
the resources that use them (mostly in `03-eks.tf`, `08-velero.tf`, and
`09-iam-github.tf`) instead of new variables, since they were never
overridable through `terraform.tfvars` in the first place.

## Resource renames

- The Velero backup module's `aws_s3_bucket.main` (and its sibling
  `aws_s3_bucket_*` sub-resources) is renamed to `aws_s3_bucket.velero` to
  keep bucket resource names unique and self-descriptive now that everything
  lives in one root module.

## Usage

Depends on [`../bootstrap`](../bootstrap) already applied (state bucket + GitHub OIDC).

```bash
cd platform/terraform/bootstrap
./scripts/generate-backend-hcl.sh alpha

cd ../01-aws
# or: ./scripts/create-alpha.sh
terraform init -backend-config=envs/alpha.backend.hcl
terraform plan  -var-file=envs/alpha.tfvars
terraform apply -var-file=envs/alpha.tfvars
```

### Scripts in this folder

| Script | Purpose |
|--------|---------|
| `scripts/create-alpha.sh` | init + plan + apply for alpha |
| `scripts/destroy-alpha.sh` | destroy alpha (ECR force_delete sync first) |
| `scripts/seed-platform-secret.sh` | seed Secrets Manager from outputs |

Deploy-approval scripts (`approve` / `revoke` / `status`) live in
`../bootstrap/scripts/` — they tag IAM roles created by bootstrap.

Any secret-bearing variables (e.g. `redis_auth_token`) should be supplied via
`TF_VAR_*` or `-var`, never committed to `envs/alpha.tfvars`.

## What this stack creates

* VPC (`10.20.0.0/16`), 2 public + 2 private subnets, IGW, NAT Gateway
* ALB / EKS-nodes / RDS / Redis security groups
* EKS cluster + managed node group, OIDC provider, and IRSA roles for VPC
  CNI, EBS CSI, AWS Load Balancer Controller, External Secrets Operator, and
  Velero
* RDS PostgreSQL instance (private, EKS-only ingress)
* ElastiCache Redis replication group (private, EKS-only ingress)
* ECR repositories for every Atlas Commerce service image
* Secrets Manager container for platform runtime secrets
* S3 bucket for Velero backups
* GitHub Actions IAM roles (ECR push, EKS deploy) + EKS access entry

## Cost safety

NAT Gateway is enabled by default (~$0.045/hour plus data processing)
because the EKS node group runs in private subnets and requires outbound
internet access to pull kubelet/CNI images and register with the cluster.
Disabling it (`enable_nat_gateway = false`) without another egress path will
hang `terraform apply` on the node group for 15-30 minutes before failing,
instead of failing fast.
