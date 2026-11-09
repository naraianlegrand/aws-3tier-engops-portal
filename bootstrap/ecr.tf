# ---------------------------------------------------------------------------
# ECR: private Docker image registry for the app (see ADR 0007).
# Lives in bootstrap so images survive `terraform destroy` of the dev environment.
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  #checkov:skip=CKV_AWS_136:AES256 encryption at rest is used; a customer-managed KMS key costs ~$1/month.
  name = var.ecr_repository_name

  # Tags are git commit IDs and can never be overwritten, so every deploy points at
  # exactly the code that was tested.
  image_tag_mutability = "IMMUTABLE"

  # Basic vulnerability scan on every push (free).
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keep storage (and cost) tiny: only the 10 most recent images are kept.
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the 10 most recent images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
