# ADR 0010: Terraform CI on pull requests, read-only plan role, Checkov with inline accepted risks

- **Status:** Accepted
- **Date:** 2026-11-09

## Context
Infrastructure changes should be reviewed before they're applied: is the code formatted and valid,
does it break lint or security rules, and what exactly will it change in AWS?

## Decision
`.github/workflows/terraform-ci.yml` runs on every pull request that touches `infra/` or `bootstrap/`:

1. **`terraform fmt -check`** and **`validate`** (dev + bootstrap)
2. **tflint** (recommended rules + AWS ruleset): invalid instance types, unused variables, missing version constraints
3. **Checkov**: security misconfigurations. The build fails on any finding that isn't explicitly accepted.
4. **`terraform plan`** for `infra/envs/dev`, using a separate **read-only OIDC role** (`engops-portal-github-plan`)

`apply` is never automated. I run it locally after reading the plan (CLAUDE.md rule 2).

### Read-only plan role
- Trusted only for this repo's pull requests and `main` (immutable OIDC subject, ADR 0008).
- Can read the dev state file and describe dev resources, but can't write anything, read secret values,
  or read S3 object contents.
- Plan runs with `-lock=false`, so the role never needs write access to the state bucket.
- Every action that AWS allows to be scoped is scoped to dev/project resources. Checkov's `CKV_AWS_356`
  caught my first version, which used `ec2:Describe*` and unscoped `rds:Describe*` on `*`. I replaced them
  with an explicit list and resource ARNs. The remaining `*` actions are ones AWS can't scope.

### Checkov accepted risks (inline `#checkov:skip`, with a reason on each resource)
Skips live on the specific resource, not in a global config, so **new resources are always fully checked**.

| Category | Checks | Why accepted in dev | Production fix |
|---|---|---|---|
| Cost: KMS customer keys | CKV_AWS_145, CKV_AWS_136, CKV_AWS_158, CKV_AWS_26 | AES256/AWS-managed encryption is on; customer keys ~$1/month each | Customer-managed KMS keys |
| No domain/certificate | CKV_AWS_2, CKV_AWS_103, CKV2_AWS_20, CKV_AWS_378 | HTTP only; ALB restricted to my IP (ADR 0009) | ACM cert, HTTPS listener, redirect |
| Destroyed every session | CKV_AWS_150, CKV_AWS_293 | Deletion protection would block `terraform destroy` | Enable |
| Cost: HA/observability | CKV_AWS_157, CKV2_AWS_11, CKV_AWS_91, CKV_AWS_18, CKV_AWS_118, CKV_AWS_129, CKV2_AWS_30, CKV_AWS_353, CKV_AWS_338, CKV2_AWS_28 | Multi-AZ, flow logs, access logs, enhanced monitoring, WAF all bill hourly or per GB | Enable per policy |
| Design choices | CKV_AWS_341 (IMDS hop limit 2), CKV_AWS_161 (IAM DB auth), CKV_AWS_144 (cross-region replication vs. data residency), CKV2_AWS_62 | See ADRs 0001, 0005, 0009 | Revisit per environment |
| False positive | CKV2_AWS_5 | SGs are attached in other modules; Checkov can't follow cross-module references | none |

## Consequences
- A PR that opens SSH to the world, makes a bucket public, or disables RDS encryption fails CI.
- The plan in CI uses a placeholder for `alb_ingress_cidrs`; my real IP stays in local, gitignored tfvars.
- When dev is destroyed (most of the time), the CI plan shows a full create. That still proves the code
  plans cleanly against real AWS lookups (ECR image, AMI, SNS topic).
