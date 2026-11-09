# ---------------------------------------------------------------------------
# Private S3 bucket for request attachments (uploads/) and reports (reports/).
# The app reaches it through the VPC's S3 gateway endpoint, not the internet.
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "files" {
  #checkov:skip=CKV_AWS_145:SSE-S3 (AES256) encryption is used; SSE-KMS with a customer key costs ~$1/month plus requests.
  #checkov:skip=CKV_AWS_144:Dev - cross-region replication doubles storage and conflicts with ca-central-1 data residency (ADR 0001).
  #checkov:skip=CKV_AWS_18:Dev cost/noise - server access logging needs a separate log bucket. Production: enable.
  #checkov:skip=CKV2_AWS_62:No consumer for S3 event notifications yet.
  bucket = var.files_bucket_name

  # Dev: lets `terraform destroy` empty and delete the bucket. Production: false.
  force_destroy = var.force_destroy_bucket

  tags = { Name = var.files_bucket_name }
}

resource "aws_s3_bucket_public_access_block" "files" {
  bucket                  = aws_s3_bucket.files.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "files" {
  bucket = aws_s3_bucket.files.id
  versioning_configuration {
    status = "Enabled" # an overwritten or deleted attachment can be recovered
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "files" {
  bucket = aws_s3_bucket.files.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "files" {
  bucket = aws_s3_bucket.files.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.files]
}

data "aws_iam_policy_document" "files_tls_only" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    # s3:* is safe here: this is a DENY on a condition (standard TLS-enforcement pattern), not a grant.
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.files.arn,
      "${aws_s3_bucket.files.arn}/*",
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

resource "aws_s3_bucket_policy" "files" {
  bucket     = aws_s3_bucket.files.id
  policy     = data.aws_iam_policy_document.files_tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.files]
}
