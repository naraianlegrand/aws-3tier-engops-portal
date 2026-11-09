output "state_bucket_name" {
  description = "Goes into infra/envs/dev/backend.tf in Step 2."
  value       = aws_s3_bucket.tfstate.bucket
}

output "region" {
  value = var.region
}

output "ecr_repository_url" {
  description = "Where CI pushes the app image."
  value       = aws_ecr_repository.app.repository_url
}

output "github_ci_role_arn" {
  description = "Set as the GitHub repo variable AWS_CI_ROLE_ARN (not a secret: an ARN alone grants nothing)."
  value       = aws_iam_role.github_ci.arn
}
