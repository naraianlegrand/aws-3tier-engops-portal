variable "region" {
  type    = string
  default = "ca-central-1"
}

variable "name" {
  description = "Prefix for resource names."
  type        = string
  default     = "engops-portal-dev"
}

variable "azs" {
  type    = list(string)
  default = ["ca-central-1a", "ca-central-1b"]
}

variable "enable_nat_gateway" {
  description = "App instances need the NAT (Docker install, ECR, Secrets Manager, SSM). false only for network-only testing."
  type        = bool
  default     = true
}

variable "alb_ingress_cidrs" {
  description = "Your public IP as a /32, set in terraform.tfvars (gitignored). See terraform.tfvars.example."
  type        = list(string)
}

variable "alarm_email" {
  description = "Email for CloudWatch alarm notifications, set in terraform.tfvars (gitignored)."
  type        = string
}

variable "app_image_tag" {
  description = "Image tag (git commit ID) to deploy. null = the most recently pushed image in ECR."
  type        = string
  default     = null
}
