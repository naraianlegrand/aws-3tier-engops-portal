"""Tests run against SQLite + a temp folder: no Docker, no Postgres, no AWS needed."""

import pytest
from fastapi.testclient import TestClient

from engops.config import Settings
from engops.db import Base
from engops.main import create_app


@pytest.fixture
def settings(tmp_path) -> Settings:
    return Settings(
        database_url=f"sqlite:///{tmp_path / 'test.db'}",
        storage_backend="local",
        upload_dir=str(tmp_path / "uploads"),
        max_upload_mb=1,
    )


@pytest.fixture
def client(settings):
    app = create_app(settings)
    Base.metadata.create_all(app.state.engine)
    with TestClient(app) as c:
        yield c
    app.state.engine.dispose()


@pytest.fixture
def new_request(client) -> dict:
    resp = client.post(
        "/api/requests",
        json={
            "title": "Revit crashes when opening Level 3 model",
            "description": "Happens since the 2025.2 update.",
            "category": "revit",
            "requester": "Priya",
        },
    )
    assert resp.status_code == 201
    return resp.json()
