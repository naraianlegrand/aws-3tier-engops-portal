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
  description = "false = no NAT (saves ~$0.05/hr) when app instances aren't needed."
  type        = bool
  default     = true
}
