"""Business logic shared by the JSON API and the HTML pages."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from .models import Attachment, ServiceRequest
from .schemas import RequestCreate
from .storage import Storage, new_storage_key, safe_filename


def create_request(db: Session, data: RequestCreate) -> ServiceRequest:
    req = ServiceRequest(**data.model_dump())
    db.add(req)
    db.commit()
    db.refresh(req)
    return req


def list_requests(db: Session, status: str | None = None) -> list[ServiceRequest]:
    stmt = select(ServiceRequest).order_by(ServiceRequest.id.desc())
    if status:
        stmt = stmt.where(ServiceRequest.status == status)
    return list(db.scalars(stmt))


def get_request(db: Session, request_id: int) -> ServiceRequest | None:
    return db.get(ServiceRequest, request_id)


def update_status(db: Session, req: ServiceRequest, status: str) -> ServiceRequest:
    req.status = status
    db.commit()
    db.refresh(req)
    return req


def add_attachment(
    db: Session,
    storage: Storage,
    req: ServiceRequest,
    filename: str | None,
    content_type: str | None,
    data: bytes,
) -> Attachment:
    clean_name = safe_filename(filename)
    key = new_storage_key(req.id, clean_name)
    ctype = (content_type or "application/octet-stream")[:100]

    # Save the file first; only record it in the DB if the upload succeeded.
    storage.save(key, data, ctype)
    att = Attachment(
        request_id=req.id,
        filename=clean_name,
        storage_key=key,
        content_type=ctype,
        size_bytes=len(data),
    )
    db.add(att)
    db.commit()
    db.refresh(att)
    return att


def get_attachment(db: Session, request_id: int, attachment_id: int) -> Attachment | None:
    att = db.get(Attachment, attachment_id)
    if att is None or att.request_id != request_id:
        return None
    return att
