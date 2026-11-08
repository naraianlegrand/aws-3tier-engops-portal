"""The Alembic migration must build the same tables the models describe."""

from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect

from engops.config import get_settings

APP_DIR = Path(__file__).resolve().parents[1]


def test_migrations_upgrade_and_downgrade(tmp_path, monkeypatch):
    db_url = f"sqlite:///{tmp_path / 'migrate.db'}"
    monkeypatch.setenv("ENGOPS_DATABASE_URL", db_url)
    get_settings.cache_clear()

    cfg = Config(str(APP_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(APP_DIR / "alembic"))

    command.upgrade(cfg, "head")
    engine = create_engine(db_url)
    tables = set(inspect(engine).get_table_names())
    assert {"service_requests", "attachments", "alembic_version"} <= tables

    command.downgrade(cfg, "base")
    assert set(inspect(engine).get_table_names()) == {"alembic_version"}

    engine.dispose()
    get_settings.cache_clear()
