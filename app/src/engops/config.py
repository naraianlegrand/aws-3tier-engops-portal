"""Settings come from environment variables (prefix ENGOPS_), never from code.

Local (Docker Compose):  ENGOPS_DATABASE_URL=postgresql+psycopg://engops@db:5432/engops
AWS (EC2):               ENGOPS_DB_HOST=<rds address>  ENGOPS_DB_SECRET_ARN=<arn>
                         ENGOPS_STORAGE_BACKEND=s3     ENGOPS_FILES_BUCKET=<bucket>
"""

from functools import lru_cache
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="ENGOPS_")

    # Option A (local/tests): a full database URL.
    database_url: str | None = None

    # Option B (AWS): host + secret ARN. The password is fetched from Secrets Manager at connect time.
    db_host: str | None = None
    db_port: int = 5432
    db_name: str = "engops"
    db_secret_arn: str | None = None

    aws_region: str = "ca-central-1"

    # Where attachments go: a local folder (dev) or the project S3 bucket (AWS).
    storage_backend: Literal["local", "s3"] = "local"
    upload_dir: str = "/data/uploads"
    files_bucket: str | None = None
    max_upload_mb: int = 10


@lru_cache
def get_settings() -> Settings:
    return Settings()
