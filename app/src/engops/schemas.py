"""Pydantic models: validate everything that comes in, shape everything that goes out."""

from datetime import datetime
from typing import Literal, get_args

from pydantic import BaseModel, ConfigDict, Field

# Example categories for an engineering firm's internal tooling team. Easy to change.
Category = Literal["revit", "autocad", "template", "software", "hardware", "other"]
Status = Literal["open", "in_progress", "resolved"]

CATEGORIES: tuple[str, ...] = get_args(Category)
STATUSES: tuple[str, ...] = get_args(Status)


class RequestCreate(BaseModel):
    title: str = Field(min_length=3, max_length=200)
    description: str = Field(default="", max_length=5000)
    category: Category
    requester: str = Field(min_length=1, max_length=100)


class StatusUpdate(BaseModel):
    status: Status


class AttachmentOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    filename: str
    content_type: str
    size_bytes: int
    uploaded_at: datetime


class RequestOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    description: str
    category: str
    status: str
    requester: str
    created_at: datetime
    updated_at: datetime
    attachments: list[AttachmentOut] = []
