# ADR 0007: ECR repository in bootstrap, immutable commit-ID tags, images built in CI

- **Status:** Accepted
- **Date:** 2026-11-08

## Context
The app runs as a Docker image pulled from ECR. The dev environment is destroyed after every session.
Docker Desktop can't run on my laptop: a WSL bug (`0x8007273f`) on this Windows build stops its Linux VM from starting.

## Options considered
1. **ECR repo in the dev environment:** every `destroy` deletes the images, so I'd rebuild and re-push every session.
2. **ECR repo in `bootstrap/`:** permanent, about $0.02/month for a few images.
3. **Tag images `latest`:** easy, but you can't tell which code is running, and a push silently changes production.
4. **Tag images with the git commit ID, immutable:** every image maps to an exact commit and can't be overwritten.

## Decision
ECR in `bootstrap/` with `IMMUTABLE` tags set to the commit ID. Images are built by GitHub Actions on a
Linux runner, not on my laptop. That works around the local Docker problem and matches how teams ship images.

## Consequences
- `terraform destroy` in dev never loses images, and redeploys are fast.
- Rolling back means deploying an older commit ID.
- Scan-on-push gives a free basic vulnerability report for each image.
- A lifecycle rule keeps only the 10 newest images, so storage stays tiny.
- The image is built on an x86_64 runner, so EC2 instances must be x86 (e.g. t3.micro), not Graviton.
