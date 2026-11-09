# ---------------------------------------------------------------------------
# Read-only role for `terraform plan` in CI (Step 8, ADR 0010).
# Separate from the image-push role: each role does one job.
# It can READ infrastructure and the dev state file, but can't change anything,
# and can't read secret values or object contents.
# ---------------------------------------------------------------------------
locals {
  account_id        = data.aws_caller_identity.current.account_id
  dev_prefix        = "engops-portal-dev"
  files_bucket_arn  = "arn:aws:s3:::${local.dev_prefix}-files-${local.account_id}"
  dev_state_key_arn = "${aws_s3_bucket.tfstate.arn}/dev/terraform.tfstate"
}

# WHO: pull requests and manual runs on main, from this repo only.
data "aws_iam_policy_document" "github_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${var.github_oidc_sub_prefix}:pull_request",
        "${var.github_oidc_sub_prefix}:ref:refs/heads/main",
      ]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "engops-portal-github-plan"
  description          = "GitHub Actions: read-only terraform plan for infra/envs/dev"
  assume_role_policy   = data.aws_iam_policy_document.github_plan_trust.json
  max_session_duration = 3600
}

# WHAT: read-only.
data "aws_iam_policy_document" "github_plan" {
  # Read the dev state. No write: CI runs plan with -lock=false, so it never creates a lock file.
  statement {
    sid       = "ReadDevState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = [local.dev_state_key_arn]
  }
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }

  # Describe/List APIs that AWS does NOT allow to be scoped to a resource
  # (they return AccessDenied if you try). Metadata-only reads.
  statement {
    sid    = "DescribeUnscopableApis"
    effect = "Allow"
    actions = [
      # EC2 reads Terraform needs for the network + compute modules (explicit list, no ec2:Describe*).
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeRouteTables",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeAddresses",
      "ec2:DescribeAddressesAttribute",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeVpcEndpointServices",
      "ec2:DescribePrefixLists",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeImages",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeTags",
      "elasticloadbalancing:Describe*",
      "autoscaling:Describe*",
      "logs:DescribeLogGroups",
      "sns:ListTopics",
    ]
    resources = ["*"]
  }

  # Reads that CAN be scoped: project/dev resources only.
  statement {
    sid       = "ReadProjectVpcAttributes"
    effect    = "Allow"
    actions   = ["ec2:DescribeVpcAttribute"]
    resources = ["arn:aws:ec2:${var.region}:${local.account_id}:vpc/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["engops-portal"]
    }
  }
  statement {
    sid       = "ReadDevAlarms"
    effect    = "Allow"
    actions   = ["cloudwatch:DescribeAlarms"]
    resources = ["arn:aws:cloudwatch:${var.region}:${local.account_id}:alarm:${local.dev_prefix}-*"]
  }
  statement {
    sid    = "ReadDevRds"
    effect = "Allow"
    actions = [
      "rds:DescribeDBInstances",
      "rds:DescribeDBSubnetGroups",
      "rds:ListTagsForResource",
    ]
    resources = [
      "arn:aws:rds:${var.region}:${local.account_id}:db:${local.dev_prefix}-*",
      "arn:aws:rds:${var.region}:${local.account_id}:subgrp:${local.dev_prefix}-*",
    ]
  }
  statement {
    sid       = "ReadDevAlarmTags"
    effect    = "Allow"
    actions   = ["cloudwatch:ListTagsForResource"]
    resources = ["arn:aws:cloudwatch:${var.region}:${local.account_id}:alarm:${local.dev_prefix}-*"]
  }
  statement {
    sid       = "ReadAppLogGroupTags"
    effect    = "Allow"
    actions   = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:/engops-portal/*"]
  }

  # IAM: only the dev app role and instance profile.
  statement {
    sid    = "ReadDevIam"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:GetInstanceProfile",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.dev_prefix}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${local.dev_prefix}-*",
    ]
  }

  # S3: bucket CONFIGURATION of the dev files bucket only. No s3:GetObject: can't read uploads.
  statement {
    sid    = "ReadFilesBucketConfig"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucket*",
      "s3:GetEncryptionConfiguration",
      "s3:GetLifecycleConfiguration",
      "s3:GetReplicationConfiguration",
      "s3:GetAccelerateConfiguration",
    ]
    resources = [local.files_bucket_arn]
  }

  # ECR: look up the repo and the latest image tag (no pull, no push).
  statement {
    sid       = "ReadEcrMetadata"
    effect    = "Allow"
    actions   = ["ecr:DescribeRepositories", "ecr:DescribeImages", "ecr:ListTagsForResource"]
    resources = [aws_ecr_repository.app.arn]
  }

  # SNS: read the alerts topic the alarms publish to.
  statement {
    sid       = "ReadAlertsTopic"
    effect    = "Allow"
    actions   = ["sns:GetTopicAttributes", "sns:ListTagsForResource"]
    resources = [aws_sns_topic.alerts.arn]
  }
}

resource "aws_iam_role_policy" "github_plan" {
  name   = "read-only-plan"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.github_plan.json
}
