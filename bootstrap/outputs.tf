output "state_bucket_name" {
  description = "Goes into infra/envs/dev/backend.tf in Step 2."
  value       = aws_s3_bucket.tfstate.bucket
}

output "region" {
  value = var.region
}
