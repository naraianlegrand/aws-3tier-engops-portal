"""Minimal HTML pages (Jinja templates). Function over design."""

from pathlib import Path

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from pydantic import ValidationError
from sqlalchemy.orm import Session

from . import crud
from .config import Settings
from .deps import get_app_settings, get_db, get_storage, read_upload
from .schemas import CATEGORIES, STATUSES, RequestCreate, StatusUpdate
from .storage import Storage

templates = Jinja2Templates(directory=str(Path(__file__).parent / "templates"))
ui_router = APIRouter(include_in_schema=False)


def _render_index(request: Request, db: Session, status_filter: str | None, errors=None, form=None):
    return templates.TemplateResponse(
        request,
        "index.html",
        {
            "requests": crud.list_requests(db, status_filter),
            "categories": CATEGORIES,
            "statuses": STATUSES,
            "status_filter": status_filter,
            "errors": errors or [],
            "form": form or {},
        },
        status_code=422 if errors else 200,
    )


@ui_router.get("/", response_class=HTMLResponse)
def index(request: Request, status: str | None = None, db: Session = Depends(get_db)):
    return _render_index(request, db, status if status in STATUSES else None)


@ui_router.post("/requests")
def create_from_form(
    request: Request,
    title: str = Form(""),
    description: str = Form(""),
    category: str = Form(""),
    requester: str = Form(""),
    db: Session = Depends(get_db),
):
    form = {"title": title, "description": description, "category": category, "requester": requester}
    try:
        data = RequestCreate(**form)
    except ValidationError as exc:
        errors = [f"{e['loc'][0]}: {e['msg']}" for e in exc.errors()]
        return _render_index(request, db, None, errors=errors, form=form)
    req = crud.create_request(db, data)
    return RedirectResponse(f"/requests/{req.id}", status_code=303)


@ui_router.get("/requests/{request_id}", response_class=HTMLResponse)
def detail(request: Request, request_id: int, db: Session = Depends(get_db)):
    req = crud.get_request(db, request_id)
    if req is None:
        raise HTTPException(status_code=404, detail="Request not found")
    return templates.TemplateResponse(request, "detail.html", {"req": req, "statuses": STATUSES})


@ui_router.post("/requests/{request_id}/status")
def update_status_from_form(request_id: int, status: str = Form(...), db: Session = Depends(get_db)):
    req = crud.get_request(db, request_id)
    if req is None:
        raise HTTPException(status_code=404, detail="Request not found")
    try:
        data = StatusUpdate(status=status)
    except ValidationError:
        raise HTTPException(status_code=422, detail="Invalid status")
    crud.update_status(db, req, data.status)
    return RedirectResponse(f"/requests/{request_id}", status_code=303)


@ui_router.post("/requests/{request_id}/attachments")
async def upload_from_form(
    request_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    storage: Storage = Depends(get_storage),
    settings: Settings = Depends(get_app_settings),
):
    req = crud.get_request(db, request_id)
    if req is None:
        raise HTTPException(status_code=404, detail="Request not found")
    data = await read_upload(file, settings.max_upload_mb)
    crud.add_attachment(db, storage, req, file.filename, file.content_type, data)
    return RedirectResponse(f"/requests/{request_id}", status_code=303)
