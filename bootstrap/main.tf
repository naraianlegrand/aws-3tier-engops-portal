# Who am I? Used to make the bucket name globally unique.
data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Terraform remote state bucket
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) encryption is used; SSE-KMS with a customer key costs ~$1/month (ADR 0002).
  #checkov:skip=CKV_AWS_144:Cross-region replication would copy state outside Canada (ADR 0001). Versioning covers recovery.
  #checkov:skip=CKV_AWS_18:Access logging needs a separate log bucket. Production: enable, or use CloudTrail data events.
  #checkov:skip=CKV2_AWS_62:No consumer for S3 event notifications.
  # S3 bucket names are global across ALL AWS accounts; the account ID makes it unique.
  bucket = "engops-portal-tfstate-${data.aws_caller_identity.current.account_id}"

  # Safety net: Terraform refuses to destroy this bucket. Losing state means
  # losing track of every resource Terraform manages.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning keeps every previous state file, so a corrupted state can be rolled back.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt at rest. SSE-S3 (AES256) is free; a customer-managed KMS key would cost ~$1/month.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State can contain sensitive values. It must never be public.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Keep cost ~$0: delete old state versions after 90 days, clean up failed uploads.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# Reject any request that isn't over HTTPS.
data "aws_iam_policy_document" "tfstate_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    # s3:* is safe here: this is a DENY on a condition (standard TLS-enforcement pattern), not a grant.
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_tls_only.json

  # Public access block must exist first, or AWS may reject the policy.
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# ---------------------------------------------------------------------------
# Cost guard. Lives here (never destroyed), not in the dev env (destroyed after every demo).
# The first 2 budgets per account are free.
# ---------------------------------------------------------------------------
resource "aws_budgets_budget" "monthly" {
  name         = "engops-portal-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Track GROSS usage (before Free-plan credits), so alerts show how fast credits are burning.
  cost_types {
    include_credit = false
    include_refund = false
  }

  # Early warning: actual spend passes 10% ($1).
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 10
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # Actual spend passes 100% ($10).
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  # AWS forecasts we'll pass $10 this month (e.g. something left running).
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
