# bootstrap/

One-time, **never destroyed** layer:
- S3 bucket for Terraform remote state (versioned, encrypted, private, HTTPS-only)
- AWS Budgets alert ($1 early warning, $10 actual, $10 forecasted)

Uses **local state** (chicken-and-egg: it creates the remote-state bucket).
`terraform.tfstate` here is gitignored. If it's lost, re-import the resources with `terraform import`.

```powershell
$env:AWS_PROFILE = "engops"
Copy-Item terraform.tfvars.example terraform.tfvars   # then edit the email
terraform init
terraform plan
terraform apply
```
