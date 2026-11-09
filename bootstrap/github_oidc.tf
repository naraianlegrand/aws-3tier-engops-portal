# ---------------------------------------------------------------------------
# GitHub Actions -> AWS with OIDC: no long-lived AWS keys stored in GitHub (see ADR 0008).
#
# How it works:
#  1. A workflow job asks GitHub for a signed token saying "I am repo X, branch Y".
#  2. It sends the token to AWS STS (AssumeRoleWithWebIdentity).
#  3. AWS checks the signature with GitHub's OIDC provider registered below, checks the
#     trust policy conditions, and returns temporary credentials (expire within an hour).
# ---------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# WHO may assume the role: only workflows from this repo, on the main branch.
data "aws_iam_policy_document" "github_ci_trust" {
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

    # Exact match: a fork, another repo, another branch or a pull request can't use this role.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_ci" {
  name                 = "engops-portal-github-ci"
  description          = "GitHub Actions (main branch of ${var.github_repository}): push app images to ECR"
  assume_role_policy   = data.aws_iam_policy_document.github_ci_trust.json
  max_session_duration = 3600
}

# WHAT the role may do: push images to the one project repository. Nothing else.
data "aws_iam_policy_document" "github_ci" {
  # ECR login token. AWS requires Resource "*": GetAuthorizationToken is account-level
  # and can't be scoped to a repository. It grants nothing by itself.
  statement {
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPushProjectRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability", # skip uploading layers that already exist
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage", # docker checks whether the image manifest already exists
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "github_ci" {
  name   = "push-app-image"
  role   = aws_iam_role.github_ci.id
  policy = data.aws_iam_policy_document.github_ci.json
}
