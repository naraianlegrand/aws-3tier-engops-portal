variable "region" {
  description = "AWS region for the state bucket."
  type        = string
  default     = "ca-central-1"
}

variable "budget_alert_email" {
  description = "Email address that receives AWS Budgets alerts. Set it in terraform.tfvars (gitignored)."
  type        = string
}

variable "monthly_budget_usd" {
  description = "Monthly budget limit in USD."
  type        = number
  default     = 10
}
