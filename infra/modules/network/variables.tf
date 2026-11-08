variable "name" {
  description = "Prefix for resource Name tags, e.g. engops-portal-dev."
  type        = string
}

variable "vpc_cidr" {
  description = "IP range for the whole VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones to spread subnets across (2 for this project)."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "One per AZ. Holds the ALB and the NAT Gateway."
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "One per AZ. Holds the EC2 app instances (private)."
  type        = list(string)
}

variable "db_subnet_cidrs" {
  description = "One per AZ. Holds RDS (private, no internet route)."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Create the NAT Gateway (~$0.05/hr). Set false to save cost when app instances aren't running."
  type        = bool
  default     = true
}
