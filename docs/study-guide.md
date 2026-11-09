# Study Guide: EngOps Portal (AWS 3-Tier with Terraform)

Everything explained while building Phase 0, in one place: the concepts, what each command does,
the console clicks it replaces, the decisions, and every checkpoint question with an answer outline.
**Use this to study, then write your own answers in [interview-notes.md](interview-notes.md).**

---

## Part 1: The big picture (say this in 60 seconds)

> A request tracker for engineering teams runs on a three-tier AWS stack in ca-central-1.
> **Presentation:** an Application Load Balancer in public subnets. **Application:** a FastAPI container on an
> EC2 Auto Scaling Group in private subnets. **Data:** RDS PostgreSQL in isolated database subnets, plus S3.
> Security groups are chained (ALB → app → DB). IAM is least privilege. Everything is Terraform with remote
> state; one `apply` builds 56 resources and one `destroy` removes them. CI uses GitHub Actions with OIDC.

```
Browser (my IP) ─80─▶ ALB (public) ─8000─▶ EC2/Docker (private app) ─5432─▶ RDS (private DB)
                                              │ S3 via gateway endpoint
                                              │ out to AWS APIs via NAT
                                              └ password from Secrets Manager
```

---

## Part 2: Terraform basics

| Command | What it does | Talks to AWS? | Console equivalent |
|---|---|---|---|
| `terraform init` | Downloads providers/modules, connects to the backend (state bucket). Rerun when you add a module. | Only to the state bucket | – |
| `terraform validate` | Checks syntax, required arguments, references, types. Can't catch "bucket name taken" or missing permissions. | No | A form checking empty required fields |
| `terraform fmt` | Formats code the standard way (`-check` only reports) | No | – |
| `terraform plan -out=tfplan` | Compares code vs. state vs. real AWS; lists create (+), change (~), destroy (-). Saves the exact plan. | Read-only | Filling the wizard and reading the summary, *without* clicking Create |
| `terraform apply tfplan` | Does exactly what the saved plan said. No second prompt. Billing starts. | Yes | Clicking **Create** |
| `terraform destroy` | Deletes everything in this environment | Yes | Deleting it all by hand |
| `terraform untaint <addr>` | "It's fine, don't replace it" after a failed-but-actually-OK create | State only | – |
| `-target=<addr>` | Plan/apply one resource only. Emergency tool; can make state drift. | – | – |
| `-var="x=y"` / `terraform.tfvars` | Supplies variable values. tfvars is gitignored; commit `.tfvars.example`. | – | – |

**Key ideas**
- **Declarative:** you describe the end state; Terraform works out the steps. The NAT "switch" (`enable_nat_gateway`) works by describing a different end state, not by issuing "delete NAT".
- **Always read the plan.** Check the counts (`X to add, Y to change, Z to destroy`). Any unexpected `destroy` = stop.
- **Modules** = reusable folders (network, security, data, compute, monitoring). The `envs/dev` root wires them together.
- **Terraform orders resources, not modules.** Security uses data's secret ARN and data uses security's DB security group; there's no cycle because the order is db-sg → RDS → secret → IAM policy.
- **`count` / `for_each`:** create one resource per AZ or per CIDR.
- **`default_tags`:** tags every resource (Project, Owner, Env, ManagedBy). Resources launched *by the ASG* need tags in the launch template instead.
- **Provider lock file** (`.terraform.lock.hcl`) is committed (same provider versions everywhere); the `.terraform/` folder is not.

---

## Part 3: Step by step

### Step 0: Repo hygiene
- `.gitignore`: state, tfvars, `.env`, keys, `.terraform/`. **State can contain secrets.**
- `.gitattributes`: force LF line endings, because Windows CRLF breaks Linux startup scripts.
- ADRs = Architecture Decision Records: context → options → decision → consequences.

### Step 1: Bootstrap (never destroyed)
**Built:** S3 state bucket (versioning, SSE-S3 encryption, public access block, HTTPS-only policy, lifecycle rule, `prevent_destroy`) + AWS Budget ($1 / $10 actual, $10 forecast).
Later added: alerts SNS topic, ECR repo, GitHub OIDC provider + 2 CI roles.

**Console equivalent:** S3 → Create bucket (block public access, versioning, encryption) → Permissions → bucket policy → Management → lifecycle rule; Billing → Budgets → Create budget.

**Concepts**
- **State = Terraform's memory:** maps `aws_vpc.this` → `vpc-0abc…`. Lose it and Terraform tries to create everything again.
- **Remote state (S3):** shared between laptop and CI; versioning keeps a history of every change (you can roll back, and it's an audit trail).
- **Locking (`use_lockfile = true`, Terraform ≥ 1.10):** apply creates `terraform.tfstate.tflock`; a second apply gets "Error acquiring the state lock". No DynamoDB table needed anymore.
- **Why bootstrap uses local state:** it creates the bucket that would hold its state (chicken-and-egg).
- **Why the budget lives in bootstrap:** destroying dev must never delete the cost guard (ADR 0002).
- **AWS account:** IAM user `day2day` in group `admin`, MFA. Never root keys. (Upgrade path: IAM Identity Center/SSO.)

**Checkpoint questions**
1. *Why remote state?* Shared, versioned, encrypted, survives a lost laptop, and CI can read it.
2. *What happens if two people apply at once?* The lock file blocks the second; without it, both could create duplicates and corrupt state.
3. *Why does bootstrap use local state?* It creates the remote-state bucket itself.
4. *Why never commit `terraform.tfstate`?* It can contain secrets and resource IDs, and Git can't lock it.
5. *Why commit `.terraform.lock.hcl` but not `.terraform/`?* The lock pins provider versions (reproducible); the folder is downloaded binaries.

### Step 2: Network
**Built:** VPC `10.0.0.0/16`, 2 AZs (ca-central-1a/b), 6 subnets: public `10.0.0.x/1.x`, app `10.0.10.x/11.x`, db `10.0.20.x/21.x`; IGW; one NAT + Elastic IP; 3 route tables; S3 gateway endpoint; locked-down default SG.

**Console equivalent:** VPC → Create VPC → "VPC and more" (2 AZs, 1 NAT "in 1 AZ", S3 endpoint), plus a separate DB route table with no internet route.

**Concepts**
- **Subnet = a room in the building (VPC), on one floor (AZ).** "Public" is not a checkbox: a subnet is public because its **route table** sends `0.0.0.0/0` to the **Internet Gateway**.

| Subnet | `0.0.0.0/0` goes to | So it's |
|---|---|---|
| public | Internet Gateway (two-way door) | public: ALB, NAT |
| app | NAT Gateway (one-way door, out only) | private, can go out |
| db | nowhere (only `local`) | fully isolated |

- **NAT Gateway:** lets private instances start outbound connections (ECR, Secrets Manager, SSM, updates); nothing can come in. ~$0.05/hr, billed per started hour.
- **One NAT vs. two (ADR 0003):** half the cost; if AZ-a fails, AZ-b loses outbound access. Production: one per AZ.
- **NAT instance alternative:** ~10× cheaper but you patch it and it's a single point of failure.
- **S3 gateway endpoint:** free; S3 traffic stays on AWS's network and skips NAT charges.
- **Main route table:** AWS creates one per VPC as a fallback; ours is unused because every subnet is explicitly associated.
- **Default VPC** (`172.31.0.0/16`) exists in every region with public subnets; many companies delete it.

**Checkpoint questions**
1. *Why do private subnets need a NAT?* Outbound-only internet access (image pulls, AWS APIs, updates) without being reachable.
2. *Why is the DB subnet separate from the app subnet?* Its own route table with no internet route at all, plus a separate blast radius.

### Step 3: Security
**Built:** 3 security groups chained by reference; EC2 IAM role + instance profile + least-privilege inline policy + SSM managed policy.

**Console equivalent:** EC2 → Security Groups → in **Source**, pick another security group instead of an IP. IAM → Roles → Create → trusted entity EC2.

**Concepts**
- **SG chain:** `alb-sg` accepts 80 from allowed IPs → `app-sg` accepts 8000 only from `alb-sg` → `db-sg` accepts 5432 only from `app-sg`. Referencing SGs means it works whatever the IPs are.
- **Outbound is restricted too:** ALB → app only; app → DB + 443; DB → nothing. SGs are **stateful**, so replies still flow back.
- **Separate rule resources** avoid a cycle (alb-sg egress refers to app-sg, app-sg ingress refers to alb-sg).
- **Role vs. instance profile:** the role is the badge (permissions + trust policy saying *who* can wear it); the instance profile is the badge holder that attaches it to EC2.
- **Least privilege:** S3 only `uploads/*` and `reports/*`; ECR pull from one repo; logs to one group; one secret. `ecr:GetAuthorizationToken` must be `*` (AWS limitation, commented). **Don't grant permissions for things that don't exist yet.**
- **SSM instead of SSH (ADR 0004):** no port 22, no keys, IAM-controlled access, can be audited.

**Checkpoint question**
- *Walk a request from browser to database and name the rule for each hop:* browser → ALB (alb-sg ingress 80 from my IP) → app (alb-sg egress 8000 to app-sg + app-sg ingress 8000 from alb-sg) → RDS (app-sg egress 5432 to db-sg + db-sg ingress 5432 from app-sg). Replies return because SGs are stateful.

### Step 4: Data
**Built:** DB subnet group, RDS PostgreSQL 17 `db.t4g.micro` (encrypted, not public, single-AZ, 1-day backups), private S3 bucket (block public access, SSE-S3, versioning, lifecycle, HTTPS-only).

**Console equivalent:** RDS → Create database → PostgreSQL → "Manage master credentials in AWS Secrets Manager" ✅ → Public access: No → SG `db-sg`.

**Concepts**
- **`manage_master_user_password = true` (ADR 0005):** RDS generates and rotates the password in Secrets Manager. Never in code, Git, tfvars **or Terraform state**. (A `random_password` would end up in state.)
- The app role can call `GetSecretValue` on **that one ARN**. The app caches it for 5 minutes, because rotation changes it.
- Dev settings so destroy works: `skip_final_snapshot`, no deletion protection, `force_destroy` on the bucket (production: the opposite).

**Checkpoint question**
- *How does the app get the DB password without it being in code?* The instance role reads the RDS-managed secret from Secrets Manager at connect time; the code only knows the secret's ARN (from an environment variable).

### Step 5: App
**Built:** FastAPI + SQLAlchemy + Alembic migrations, Jinja HTML pages, JSON API, file attachments (local folder or S3), 18 pytest tests (SQLite), Dockerfile (non-root), Compose file.

**Concepts**
- **Same code, different environment variables:** local `ENGOPS_DATABASE_URL`; AWS `ENGOPS_DB_HOST` + `ENGOPS_DB_SECRET_ARN` + `STORAGE_BACKEND=s3`.
- **Liveness vs. readiness (ADR 0006):** `/health` (process up) is what the ALB checks; `/health/ready` also checks the DB. If the ALB checked the DB, a DB outage would make the ASG replace *every* healthy instance in a loop.
- **Downloads are always `attachment` + `nosniff`,** so an uploaded HTML file can't run scripts. Filenames are sanitized; uploads are size-limited.
- **Alembic** = version control for the schema; runs `upgrade head` at container start (production: a separate deploy step).
- **Images built in CI, not on the laptop (ADR 0007):** tag = git commit ID, **immutable**, scan on push, keep the 10 newest. ECR lives in bootstrap so destroy doesn't delete images.
- `--platform linux/amd64 --provenance=false` → one plain image (scannable, and the lifecycle rule counts it correctly). x86 image → x86 EC2 (t3.micro).

**Checkpoint question**
- *What does the health check endpoint do for the ALB?* The ALB calls `/health` every 15 s; 3 failures = unhealthy → no traffic sent to it, and the ASG (health check type ELB) replaces it. 2 successes = healthy again.

### Step 6: Compute
**Built:** CloudWatch log group, launch template (AL2023, t3.micro, IMDSv2, encrypted gp3, user data), ALB + target group + listener, ASG (min 1 / max 2 / desired 1, both app subnets), target-tracking scaling at 60% CPU.

**Console equivalent:** EC2 → Launch Templates → Create; Auto Scaling Groups → Create; Load Balancers → Create ALB → target group with `/health`.

**What user data does at first boot:** install Docker → IMDSv2 token → instance ID → `aws ecr get-login-password | docker login` (instance role, no keys) → `docker pull <tag>` → `docker run` with DB host, secret ARN, bucket, awslogs driver.

**Concepts**
- **Health check type ELB + 300 s grace period:** the ASG trusts the ALB; the grace period covers Docker install + image pull.
- **IMDSv2 required:** stops SSRF-style theft of role credentials. **Hop limit 2** so the container (one extra network hop) can still get credentials.
- **Rolling instance refresh:** new image tag or AMI → new launch template version → instances replaced one at a time.
- **ALB restricted to my IP** (in gitignored tfvars) because the app has no login.
- **Debugging:** timeout = a network rule blocks you (SG/NACL/port); 502/503 = you reached the ALB but the app isn't answering. Logs: `/var/log/cloud-init-output.log` and `docker logs engops` via SSM.

**Checkpoint question**
- *What happens when an instance fails its health check?* The ALB stops routing to it (after 3 failures); the ASG marks it unhealthy, terminates it, and launches a replacement from the launch template; the new one gets traffic after 2 passing checks. (Proven in screenshot 06.)

### Step 7: Monitoring
**Built:** 5 alarms → SNS email: no healthy hosts (< 1 for 2 min), ALB 5xx (> 5 in 5 min), app 5xx, RDS free storage (< 2 GiB), EC2 CPU (> 80% for 10 min). The SNS topic lives in bootstrap, so the email is confirmed once.

**Concepts**
- **HealthyHostCount < 1, not UnHealthyHostCount > 0:** once the ASG removes the bad instance, the unhealthy count goes back to 0 while nothing is serving.
- `treat_missing_data`: "breaching" for host count (no data is bad), "notBreaching" for error counts (no errors is good).
- **SNS needs the subscription confirmed,** otherwise nothing is delivered (anti-spam).
- SNS isn't encrypted: CloudWatch can't publish to a topic using the AWS-managed `aws/sns` key.

**Checkpoint question**
- *Which alarm fires first if the app crashes?* `no-healthy-hosts` (ALB notices within ~45 s; the alarm needs 2 minutes at zero). `alb-5xx` follows if users hit 502/503 meanwhile.

### Step 8: CI/CD
**Built:**
- `app-ci.yml`: tests on every push/PR; on main → OIDC → build → push to ECR.
- `terraform-ci.yml` on PRs: fmt → validate → tflint → Checkov → read-only `plan`.
- Two OIDC roles: **push-only** (main branch) and **read-only plan** (PRs + main).

**Concepts**
- **OIDC (ADR 0008):** GitHub signs a token ("repo X, branch Y"); AWS checks the trust policy (`aud` = sts.amazonaws.com, exact `sub`) and returns credentials that expire within an hour. No AWS keys in GitHub. Role ARNs are *variables*, not secrets.
- **Immutable subject:** `repo:owner@ID/name@ID:ref:refs/heads/main`. The numeric IDs stop a recreated repo with the same name from assuming your role. (Renaming the repo would break the trust policy.)
- **Read-only plan role:** reads state + describes resources; `-lock=false` so it never writes; can't read secrets or S3 objects.
- **Checkov (ADR 0010):** security scanner. Accepted dev risks are inline `#checkov:skip=ID:reason` **on each resource** (a risk register); anything new fails CI. It caught over-broad permissions in my own plan role.
- **tflint:** catches invalid instance types, unused variables, missing version constraints.
- **apply stays manual,** after reading the plan.

**Checkpoint question**
- *Why OIDC instead of AWS keys in GitHub secrets?* Keys never expire, must be rotated by hand, and anyone who gets them can use them from anywhere. OIDC tokens are short-lived, scoped to one job, and only accepted from my repo/branch.

### Step 9: Proof
Apply (56) → use through ALB → S3 upload → crash test (`docker stop engops`) → self-heal + alarm email → destroy (56) → apply again → destroy. Screenshots in [screenshots/](screenshots/).

---

## Part 4: What broke (your best interview stories)

| Problem | Root cause | Fix | Lesson |
|---|---|---|---|
| VPC "missing" in console | Console set to us-east-1; I was looking at the default VPC | Switched region to Canada (Central) | Always check the region selector |
| Docker Desktop wouldn't start (`0x8007273f`) | WSL couldn't create its VM: Hyper-V socket provider missing from Winsock | Winsock reset + features (didn't fix) → build images in GitHub Actions | Time-box environment issues; choose the path teams use anyway |
| CI: `Not authorized to perform sts:AssumeRoleWithWebIdentity` | GitHub's immutable OIDC subject (numeric IDs) ≠ my name-only trust policy | Looked up the real claim with `gh api …/oidc/customization/sub` and matched it | Read the actual token format instead of guessing |
| ECR: 3 entries per push, no scan | `docker build` pushed an index + attestation bundle | `--platform linux/amd64 --provenance=false` | Know what you actually pushed |
| ASG create failed: "Access denied … AWSServiceRoleForAutoScaling" | First ASG in a new account: service-linked role not propagated yet; AWS's retry succeeded but Terraform marked it tainted | Checked `describe-scaling-activities`, then `terraform untaint` | Read the AWS activity log before re-running |
| App URL timed out | tfvars still had the placeholder IP `203.0.113.10` | Set my real `/32`, re-applied | Timeout = network rule; 5xx = app |
| No alarm email | SNS subscription never confirmed (and it was destroyed with dev) | Moved SNS to bootstrap; confirmed once | Things that must outlive demos belong in bootstrap |
| Checkov flagged my plan role | `ec2:Describe*` / `cloudwatch:DescribeAlarms` on `*` can be scoped | Explicit actions + resource ARNs + tag condition | Scanners catch your own mistakes too |

---

## Part 5: Cost and safety
- Free plan with credits: no surprise bills until you upgrade. Budget alerts at $1 and $10.
- Running dev stack ≈ $0.12–0.15/hr (NAT, ALB + IPs, EC2, RDS). Bootstrap ≈ $0/month.
- NAT and ALB bill per *started hour*: 10 minutes costs as much as 60.
- Workflow: apply → demo → destroy the same day. After a destroy, check that nothing is left (RDS, EC2, ALB, NAT, Elastic IPs).

---

## Part 6: Interview questions from CLAUDE.md §9 (write these yourself)

| # | Question | Where to look |
|---|---|---|
| 1 | Draw the architecture; explain each tier in 60 s | Part 1, README diagram |
| 2 | Request flow browser → DB; which rule allows each hop? | Step 3 |
| 3 | Why one NAT? What changes for production? | Step 2, ADR 0003 |
| 4 | How do you manage state and prevent conflicting applies? | Step 1, ADR 0002 |
| 5 | How are secrets handled? | Step 4, ADR 0005, Step 8 (OIDC) |
| 6 | Show one least-privilege IAM policy | `infra/modules/security/iam.tf`, Step 3 |
| 7 | How would you make it production-ready? | README "Known gaps", ADR 0010 table |
| 8 | What broke and how did you fix it? | Part 4 |

### Extra questions to practise
- Why put the budget, ECR and SNS in bootstrap instead of dev?
- Why doesn't the ALB health check test the database?
- Why IMDSv2, and why hop limit 2?
- What's the difference between a security group and a NACL? (stateful vs. stateless; instance vs. subnet)
- What does `terraform plan` compare? (code vs. state vs. real infrastructure)
- What would you do if the state file got corrupted? (restore a previous S3 version)
- Why tag images with the commit ID instead of `latest`?
- Why is the plan role read-only, and why `-lock=false`?
- How does the app pick up a rotated DB password? (fetch per new connection, 5-minute cache)
