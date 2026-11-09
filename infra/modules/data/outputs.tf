output "db_address" {
  description = "Private DNS name of the database (only resolvable/reachable inside the VPC)."
  value       = aws_db_instance.this.address
}

output "db_instance_identifier" {
  description = "For CloudWatch RDS alarms."
  value       = aws_db_instance.this.identifier
}

output "db_port" {
  value = aws_db_instance.this.port
}

output "db_name" {
  value = aws_db_instance.this.db_name
}

output "db_secret_arn" {
  description = "Secrets Manager secret holding the DB username/password (created and rotated by RDS)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "files_bucket_name" {
  value = aws_s3_bucket.files.bucket
}
