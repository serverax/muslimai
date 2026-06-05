# Sakina Mobile Terraform

This Terraform module provisions isolated staging infrastructure for Sakina Mobile in UK South.

## Safety
- Apply only after verifying Azure account and subscription.
- Review plan to confirm only Sakina Mobile staging resources are touched.
- Never target non-staging clusters or namespaces.

## Usage
```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Notes
- `backend.example.tf` must be copied and adapted to `backend.tf` before remote state use.
- Do not commit real secrets in tfvars.
