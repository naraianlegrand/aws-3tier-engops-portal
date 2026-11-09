variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "ca-central-1"
}

variable "budget_alert_email" {
  description = "Email address that receives AWS Budgets alerts. Set it in terraform.tfvars (gitignored)."
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

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD."
  type        = number
  default     = 10
}
