variable "name" {
  description = "Prefix for resource names, e.g. engops-portal-dev."
  type        = string
}

variable "tags" {
  description = "Tags for EC2 instances and volumes (provider default_tags don't reach resources launched by the ASG)."
  type        = map(string)
}

# ----- Network / security (from the network and security modules) -----
variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "ALB subnets."
  type        = list(string)
}

variable "app_subnet_ids" {
  description = "Private subnets for the EC2 instances."
  type        = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_sg_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

# ----- Instances -----
variable "instance_type" {
  description = "x86_64 (the image is built for linux/amd64). t3.micro is Free-plan eligible."
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 8000
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "cpu_target_percent" {
  description = "Target-tracking scaling: add/remove instances to keep average CPU near this value."
  type        = number
  default     = 60
}

# ----- What the container needs -----
variable "image_uri" {
  description = "Full ECR image URI including the tag (commit ID)."
  type        = string
}

variable "region" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_name" {
  type = string
}

variable "db_secret_arn" {
  type = string
}

variable "files_bucket_name" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 7
}
