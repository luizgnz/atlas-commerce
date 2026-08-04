# Atlas Commerce - AWS Alpha Environment

Terraform root module for the Atlas Commerce `alpha` (development) environment, deployed to AWS Frankfurt (`eu-central-1`).

## What This Environment Creates

* One VPC: `10.20.0.0/16`
* Two public subnets across `eu-central-1a` and `eu-central-1b`
* Two private subnets across `eu-central-1a` and `eu-central-1b`
* One Internet Gateway
* One public route table with Internet access
* One private route table per Availability Zone
* NAT Gateway enabled by default — the EKS node group runs in private subnets and needs it for outbound access (see Cost Safety below)

## State Backend

Terraform state is stored remotely in the S3 backend:

```text
atlas-commerce/alpha/terraform.tfstate
```

State locking uses S3 lockfiles.

## Network Design

```text
Internet
   |
Internet Gateway
   |
Public Subnets
   |
Private Subnets
```

Public subnets have a default route to the Internet Gateway.

Private subnets have no outbound Internet route if `enable_nat_gateway` is set to `false`. Do not disable it while the EKS node group exists — the node group has no other egress path and will hang during `apply` instead of failing fast.

## Usage

`backend.hcl` is generated, not committed — it always reflects the current AWS account's state bucket. Generate it before `terraform init`:

```powershell
cd platform\terraform\bootstrap\aws-backend
.\generate-backend-hcl.sh alpha   # or the equivalent under Git Bash/WSL
cd ..\..\live\aws\alpha
```

```powershell
cd platform\terraform\live\aws\alpha

Copy-Item terraform.tfvars.example terraform.tfvars

terraform init -backend-config="backend.hcl"
terraform fmt
terraform validate
terraform plan
```

Apply reviewed changes:

```powershell
terraform plan -out tfplan
terraform apply "tfplan"
```

Verify the deployed infrastructure:

```powershell
terraform output
terraform plan
```

## Cost Safety

NAT Gateway is enabled by default (~$0.045/hour plus data processing) because the EKS node group runs in private subnets and requires outbound Internet access to pull kubelet/CNI images and register with the cluster. Disabling it will hang `terraform apply` on the node group for 15-30 minutes before failing, instead of failing fast.

Only disable it in environments with no EKS node group, or once an alternative egress path (e.g. VPC endpoints) is in place:

```hcl
enable_nat_gateway = false
```

## Module Used

This environment invokes the reusable network module:

```text
../../../modules/aws/network
```

The module is responsible for creating the VPC, subnets, route tables, Internet Gateway, and optional NAT Gateway.

