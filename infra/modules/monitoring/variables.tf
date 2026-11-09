variable "name" {
  description = "Prefix for resource names, e.g. engops-portal-dev."
  type        = string
}

variable "alarm_email" {
  description = "Where alarm notifications go. AWS sends a confirmation email that must be clicked once."
  type        = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "asg_name" {
  type = string
}

variable "db_instance_identifier" {
  type = string
}

variable "rds_free_storage_threshold_bytes" {
  description = "Alarm when free storage drops below this (default 2 GiB of the 20 GiB volume)."
  type        = number
  default     = 2147483648
}
