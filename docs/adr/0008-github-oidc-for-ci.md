# ADR 0008: GitHub Actions authenticates to AWS with OIDC, not stored access keys

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
CI needs to push images to ECR, which requires AWS credentials.

## Options considered
1. **IAM user access keys stored as GitHub secrets:** they never expire, have to be rotated by hand, and
   anyone who gets them (a leaked log, a compromised workflow) can use them from anywhere until revoked.
2. **OIDC federation:** GitHub issues a signed token per job. AWS trusts GitHub's OIDC provider and
   exchanges the token for temporary credentials, but only if the token's claims match the role's trust policy.

## Decision
OIDC. The role `engops-portal-github-ci` can be assumed only when:
- the audience is `sts.amazonaws.com`, and
- the subject is exactly `repo:naraianlegrand@48866785/aws-3tier-engops-portal@1448775678:ref:refs/heads/main`.

  This is GitHub's *immutable subject* format, which includes numeric owner and repo IDs. My first version
  used the name-only format (`repo:owner/name:...`), and AWS correctly rejected the token. The ID format is
  safer: if the repo were deleted and someone recreated it under the same name, their tokens would carry
  different IDs and couldn't assume the role.

Its permissions: push to the one `engops-portal` ECR repository (plus `ecr:GetAuthorizationToken`,
which AWS requires on `*`).

## Consequences
- No AWS secret exists anywhere in GitHub. The role ARN is stored as a plain repo *variable*, because an ARN alone grants nothing.
- Credentials last at most one hour and are scoped to a single job.
- Forks, other branches and pull requests can't assume the role. PRs still run the tests, but don't push images.
- Step 8 adds a second, read-only role for `terraform plan` in CI, with its own trust conditions.
