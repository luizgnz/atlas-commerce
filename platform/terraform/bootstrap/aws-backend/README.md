# Atlas Commerce - Terraform Backend Bootstrap

This folder creates the initial AWS resources required for Terraform remote state.

Resources:

- S3 bucket for Terraform state
- S3 bucket versioning
- S3 bucket encryption
- S3 public access block
- S3 HTTPS-only bucket policy

State locking uses the native S3 lockfile (`use_lockfile = true`, Terraform >= 1.10). No DynamoDB table is created — it would be unused dead weight alongside the S3 lockfile.

Important:

This bootstrap folder intentionally uses local Terraform state because it creates the remote backend itself.

## Generating backend.hcl for a live environment

Do not hand-type the state bucket name into a new `live/aws/<env>/backend.hcl` — copying it from memory is how `alpha`'s backend once ended up pointing at a bucket in the wrong AWS account. Generate it from this module's output instead:

```bash
cd platform/terraform/bootstrap/aws-backend
./generate-backend-hcl.sh alpha
```

This runs `terraform output -raw backend_config_template` against this module's own state and writes `../../live/aws/<env>/backend.hcl`. Run it again for every environment (`staging`, `prod`, `shared`, ...) and whenever the bootstrap is re-applied against a different AWS account.

## Usage

```bash
cd platform/terraform/bootstrap/aws-backend

cp terraform.tfvars.example terraform.tfvars

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan