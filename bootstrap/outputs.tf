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

output "alerts_topic_arn" {
  description = "SNS topic the dev alarms publish to."
  value       = aws_sns_topic.alerts.arn
}

output "github_plan_role_arn" {
  description = "Set as the GitHub repo variable AWS_PLAN_ROLE_ARN (read-only role for terraform plan in CI)."
  value       = aws_iam_role.github_plan.arn
}

output "github_ci_role_arn" {
  description = "Set as the GitHub repo variable AWS_CI_ROLE_ARN (not a secret: an ARN alone grants nothing)."
  value       = aws_iam_role.github_ci.arn
}
