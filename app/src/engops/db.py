"""Database engine. Locally it uses a plain URL; in AWS it injects credentials from Secrets Manager."""

import json
import time

from sqlalchemy import URL, Engine, create_engine, event
from sqlalchemy.orm import DeclarativeBase

from .config import Settings


class Base(DeclarativeBase):
    pass


# RDS rotates the password (every 7 days by default), so cache it briefly instead of forever.
_SECRET_TTL_SECONDS = 300
_secret_cache: dict = {"value": None, "fetched_at": 0.0}


def _db_credentials(settings: Settings) -> dict:
    now = time.monotonic()
    if _secret_cache["value"] is None or now - _secret_cache["fetched_at"] > _SECRET_TTL_SECONDS:
        import boto3  # only needed in AWS

        client = boto3.client("secretsmanager", region_name=settings.aws_region)
        secret = client.get_secret_value(SecretId=settings.db_secret_arn)["SecretString"]
        _secret_cache.update(value=json.loads(secret), fetched_at=now)
    return _secret_cache["value"]


def make_engine(settings: Settings) -> Engine:
    # Local / tests: a full URL was provided.
    if settings.database_url:
        connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
        return create_engine(settings.database_url, pool_pre_ping=True, connect_args=connect_args)

    if not (settings.db_host and settings.db_secret_arn):
        raise RuntimeError("Set ENGOPS_DATABASE_URL, or ENGOPS_DB_HOST + ENGOPS_DB_SECRET_ARN.")

    # AWS: the URL has no username/password. They are injected each time a NEW connection is opened,
    # so a rotated password is picked up automatically (after the cache expires).
    url = URL.create(
        "postgresql+psycopg",
        host=settings.db_host,
        port=settings.db_port,
        database=settings.db_name,
    )
    engine = create_engine(url, pool_pre_ping=True, pool_recycle=1800)

    @event.listens_for(engine, "do_connect")
    def _inject_credentials(dialect, conn_rec, cargs, cparams):
        creds = _db_credentials(settings)
        cparams["user"] = creds["username"]
        cparams["password"] = creds["password"]
        cparams["sslmode"] = "require"  # encrypt app <-> RDS traffic

    return engine
