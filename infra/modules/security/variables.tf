variable "name" {
  description = "Prefix for resource names, e.g. engops-portal-dev."
  type        = string
}

variable "vpc_id" {
  description = "VPC the security groups belong to."
  type        = string
}

variable "app_port" {
  description = "Port the FastAPI container listens on."
  type        = number
  default     = 8000
}

variable "files_bucket_name" {
  description = "Project S3 bucket (created in the data module). The app may only touch uploads/ and reports/."
  type        = string
}

variable "ecr_repository_name" {
  description = "ECR repo the app image is pulled from."
  type        = string
}

variable "app_log_group_name" {
  description = "CloudWatch log group the app container writes to."
  type        = string
}
