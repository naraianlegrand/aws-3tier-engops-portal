data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region

  files_bucket_arn = "arn:aws:s3:::${var.files_bucket_name}"
  ecr_repo_arn     = "arn:aws:ecr:${local.region}:${local.account_id}:repository/${var.ecr_repository_name}"
  log_group_arn    = "arn:aws:logs:${local.region}:${local.account_id}:log-group:${var.app_log_group_name}"
}

# ---------------------------------------------------------------------------
# EC2 instance role: the app server's "ID badge".
# The trust policy says WHO can wear the badge: only the EC2 service.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${var.name}-app-ec2"
  description        = "EngOps Portal app instances (least privilege)"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

# The instance profile is the "badge holder" that attaches the role to an EC2 instance.
resource "aws_iam_instance_profile" "app" {
  name = "${var.name}-app-ec2"
  role = aws_iam_role.app.name
}

# ---------------------------------------------------------------------------
# What the badge allows: every statement names specific actions AND resources.
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "app" {
  # S3: read/write/delete objects only under uploads/ and reports/ in the project bucket.
  statement {
    sid     = "S3ObjectsInAppPrefixes"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${local.files_bucket_arn}/uploads/*",
      "${local.files_bucket_arn}/reports/*",
    ]
  }

  # S3: list the bucket, but only inside those two prefixes.
  statement {
    sid       = "S3ListAppPrefixes"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.files_bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["uploads/*", "reports/*"]
    }
  }

  # ECR login token. AWS requires Resource "*": GetAuthorizationToken is account-level
  # and can't be scoped to a repository. It grants nothing by itself.
  statement {
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECR: pull images from the project repo only (no push).
  statement {
    sid    = "EcrPullProjectRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [local.ecr_repo_arn]
  }

  # CloudWatch Logs: write to the app's log group only. Terraform creates the group itself (Step 7),
  # so the app doesn't need logs:CreateLogGroup.
  statement {
    sid       = "WriteAppLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${local.log_group_arn}:*"]
  }

  # Secrets Manager: read ONE secret, the DB credentials RDS created.
  # The secret uses the AWS-managed key aws/secretsmanager, so no separate kms:Decrypt grant is needed.
  statement {
    sid       = "ReadDbSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "app" {
  name   = "${var.name}-app-least-privilege"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.app.json
}

# SSM Session Manager: shell access with no SSH, no open port 22 and no keys (see ADR 0004).
# AWS-managed policy. It contains some Resource "*" entries because the SSM agent's
# messaging APIs can't be scoped to a resource; this is the AWS-documented minimum for SSM.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
