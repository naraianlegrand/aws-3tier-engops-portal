"""FastAPI dependencies: give each request a DB session, the storage backend and settings."""

from collections.abc import Iterator

from fastapi import HTTPException, Request, UploadFile
from sqlalchemy.orm import Session

from .config import Settings
from .storage import Storage


def get_db(request: Request) -> Iterator[Session]:
    db = request.app.state.session_factory()
    try:
        yield db
    finally:
        db.close()


def get_storage(request: Request) -> Storage:
    return request.app.state.storage


def get_app_settings(request: Request) -> Settings:
    return request.app.state.settings


async def read_upload(upload: UploadFile, max_mb: int) -> bytes:
    """Read an upload, rejecting anything over the size limit."""
    max_bytes = max_mb * 1024 * 1024
    data = await upload.read(max_bytes + 1)
    if len(data) > max_bytes:
        raise HTTPException(status_code=413, detail=f"File larger than {max_mb} MB")
    if not data:
        raise HTTPException(status_code=400, detail="Empty file")
    return data
