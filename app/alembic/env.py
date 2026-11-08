"""Alembic runs migrations with the SAME engine the app uses, so in AWS it also gets
the DB password from Secrets Manager. No separate migration credentials."""

from alembic import context

from engops import models  # noqa: F401  (imports the tables so Alembic can see them)
from engops.config import get_settings
from engops.db import Base, make_engine

target_metadata = Base.metadata


def run_migrations_online() -> None:
    engine = make_engine(get_settings())
    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            render_as_batch=connection.dialect.name == "sqlite",
        )
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


if context.is_offline_mode():
    raise SystemExit("Offline (SQL script) mode is not used in this project.")

run_migrations_online()
