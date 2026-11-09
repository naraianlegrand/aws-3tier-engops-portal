variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "ca-central-1"
}

variable "budget_alert_email" {
  description = "Email that receives AWS Budgets alerts and CloudWatch alarm notifications. Set it in terraform.tfvars (gitignored)."
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repo for the app image. Must match local.ecr_repository_name in infra/envs/dev."
  type        = string
  default     = "engops-portal"
}

variable "github_repository" {
  description = "owner/name of the GitHub repo allowed to assume the CI role."
  type        = string
  default     = "naraianlegrand/aws-3tier-engops-portal"
}

variable "github_oidc_sub_prefix" {
  description = <<-EOT
    Start of the OIDC 'sub' claim GitHub sends for this repo (immutable format with numeric IDs).
    Look it up with: gh api repos/OWNER/REPO/actions/oidc/customization/sub  (field sub_claim_prefix)
  EOT
  type        = string
  default     = "repo:naraianlegrand@48866785/aws-3tier-engops-portal@1448775678"
}

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD."
  type        = number
  default     = 10
}
