# ADR 0001: Deploy to ca-central-1 (Canada Central)

- **Status:** Accepted
- **Date:** 2026-11-06

## Context
The project needs one AWS region. The target employer is an engineering consulting firm in Canada,
and engineering project data (drawings, models, client files) is often subject to
client contracts or expectations about where data is stored.

## Options considered
1. **ca-central-1 (Montreal):** data stays in Canada, low latency for Canadian users.
   Has fewer AZs and services than us-east-1, and prices are slightly higher.
2. **us-east-1 (N. Virginia):** cheapest, every service available first. Data leaves Canada.

## Decision
Use `ca-central-1` for all resources.

## Consequences
- Good talking point on **data residency**: everything, including backups and state, stays in Canada.
- Every service used (EC2, ALB, RDS, S3, Secrets Manager, ECR) is available in ca-central-1.
- Must check that 2+ AZs support the chosen instance types (ca-central-1 has ca-central-1a/b/d).
- AWS Budgets is a global service. The budget alert is not region-specific.
