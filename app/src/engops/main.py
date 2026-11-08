"""App factory. Run with:  uvicorn engops.main:create_app --factory"""

from fastapi import FastAPI
from sqlalchemy.orm import sessionmaker

from .api import api_router, health_router
from .config import Settings, get_settings
from .db import make_engine
from .storage import make_storage
from .ui import ui_router


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()

    app = FastAPI(title="EngOps Portal", version="0.1.0")

    # Created once per app; no connection is opened until the first request needs one.
    engine = make_engine(settings)
    app.state.settings = settings
    app.state.engine = engine
    app.state.session_factory = sessionmaker(bind=engine, expire_on_commit=False)
    app.state.storage = make_storage(settings)

    app.include_router(health_router)
    app.include_router(api_router)
    app.include_router(ui_router)
    return app
