# EngOps Portal app

FastAPI + SQLAlchemy + Alembic. A request tracker for engineering tool issues, with file attachments.

## Run locally (Docker, $0)

```powershell
cd app
docker compose up --build        # app + local Postgres
# open http://localhost:8000      (API docs: http://localhost:8000/docs)
docker compose down -v           # stop and delete local data
```

## Run tests (no Docker needed: SQLite + temp folder)

```powershell
cd app
python -m venv .venv
.venv\Scripts\pip install -r requirements-dev.txt
.venv\Scripts\python -m pytest
```

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Liveness, used by the ALB (no DB check, see ADR 0006) |
| GET | `/health/ready` | Readiness, which also checks the database |
| GET/POST | `/`, `/requests/{id}` | HTML pages |
| POST/GET | `/api/requests` | Create / list (filter `?status=`) |
| GET | `/api/requests/{id}` | Details + attachments |
| PATCH | `/api/requests/{id}/status` | `open` → `in_progress` → `resolved` |
| POST | `/api/requests/{id}/attachments` | Upload a file (10 MB limit) |
| GET | `/api/requests/{id}/attachments/{aid}` | Download (always served as a download) |

## Configuration (environment variables)

| Variable | Local | AWS |
|---|---|---|
| `ENGOPS_DATABASE_URL` | `postgresql+psycopg://engops@db:5432/engops` | not set |
| `ENGOPS_DB_HOST`, `ENGOPS_DB_SECRET_ARN` | not set | RDS address + secret ARN (password fetched at runtime) |
| `ENGOPS_STORAGE_BACKEND` | `local` | `s3` |
| `ENGOPS_FILES_BUCKET` | not set | project bucket |

**No authentication yet.** This is a demo of the infrastructure. In AWS, access to the ALB will be
restricted to the owner's IP address.
