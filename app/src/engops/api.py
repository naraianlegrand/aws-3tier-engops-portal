"""Health checks and the JSON API (/api/...). Phase 1 integrations will call this API."""

from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session

from . import crud
from .config import Settings
from .deps import get_app_settings, get_db, get_storage, read_upload
from .schemas import AttachmentOut, RequestCreate, RequestOut, Status, StatusUpdate
from .storage import Storage

health_router = APIRouter(tags=["health"])
api_router = APIRouter(prefix="/api", tags=["requests"])


@health_router.get("/health")
def health() -> dict:
    """Liveness: is the app process up? The ALB checks this.
    It deliberately does NOT check the database (see ADR 0006)."""
    return {"status": "ok"}


@health_router.get("/health/ready")
def ready(db: Session = Depends(get_db)) -> dict:
    """Readiness: can the app reach the database? For humans and monitoring, not the ALB."""
    try:
        db.execute(text("SELECT 1"))
    except SQLAlchemyError:
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ready"}


def _get_or_404(db: Session, request_id: int):
    req = crud.get_request(db, request_id)
    if req is None:
        raise HTTPException(status_code=404, detail="Request not found")
    return req


@api_router.post("/requests", response_model=RequestOut, status_code=201)
def create_request(data: RequestCreate, db: Session = Depends(get_db)):
    return crud.create_request(db, data)


@api_router.get("/requests", response_model=list[RequestOut])
def list_requests(status: Status | None = None, db: Session = Depends(get_db)):
    return crud.list_requests(db, status)


@api_router.get("/requests/{request_id}", response_model=RequestOut)
def get_request(request_id: int, db: Session = Depends(get_db)):
    return _get_or_404(db, request_id)


@api_router.patch("/requests/{request_id}/status", response_model=RequestOut)
def update_status(request_id: int, data: StatusUpdate, db: Session = Depends(get_db)):
    return crud.update_status(db, _get_or_404(db, request_id), data.status)


@api_router.post(
    "/requests/{request_id}/attachments", response_model=AttachmentOut, status_code=201
)
async def upload_attachment(
    request_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    storage: Storage = Depends(get_storage),
    settings: Settings = Depends(get_app_settings),
):
    req = _get_or_404(db, request_id)
    data = await read_upload(file, settings.max_upload_mb)
    return crud.add_attachment(db, storage, req, file.filename, file.content_type, data)


@api_router.get("/requests/{request_id}/attachments/{attachment_id}")
def download_attachment(
    request_id: int,
    attachment_id: int,
    db: Session = Depends(get_db),
    storage: Storage = Depends(get_storage),
):
    att = crud.get_attachment(db, request_id, attachment_id)
    if att is None:
        raise HTTPException(status_code=404, detail="Attachment not found")
    # Always a download, never rendered in the browser, so an uploaded HTML/SVG file can't run scripts.
    return Response(
        content=storage.load(att.storage_key),
        media_type="application/octet-stream",
        headers={
            "Content-Disposition": f'attachment; filename="{att.filename}"',
            "X-Content-Type-Options": "nosniff",
        },
    )
