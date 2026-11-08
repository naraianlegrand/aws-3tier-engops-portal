"""File storage with one interface and two backends: a local folder (dev) or S3 (AWS)."""

import re
import uuid
from pathlib import Path
from typing import Protocol

from .config import Settings


class Storage(Protocol):
    def save(self, key: str, data: bytes, content_type: str) -> None: ...
    def load(self, key: str) -> bytes: ...


class LocalStorage:
    def __init__(self, base_dir: str):
        self.base = Path(base_dir)

    def save(self, key: str, data: bytes, content_type: str) -> None:
        path = self.base / key
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def load(self, key: str) -> bytes:
        return (self.base / key).read_bytes()


class S3Storage:
    def __init__(self, bucket: str, region: str):
        import boto3  # only needed in AWS

        self.bucket = bucket
        # Credentials come from the EC2 instance role automatically: no keys anywhere.
        self.client = boto3.client("s3", region_name=region)

    def save(self, key: str, data: bytes, content_type: str) -> None:
        self.client.put_object(Bucket=self.bucket, Key=key, Body=data, ContentType=content_type)

    def load(self, key: str) -> bytes:
        return self.client.get_object(Bucket=self.bucket, Key=key)["Body"].read()


def make_storage(settings: Settings) -> Storage:
    if settings.storage_backend == "s3":
        if not settings.files_bucket:
            raise RuntimeError("ENGOPS_FILES_BUCKET is required when ENGOPS_STORAGE_BACKEND=s3")
        return S3Storage(settings.files_bucket, settings.aws_region)
    return LocalStorage(settings.upload_dir)


def safe_filename(name: str | None) -> str:
    """Strip any path and odd characters from a user-supplied filename."""
    name = (name or "file").replace("\\", "/").split("/")[-1]
    name = re.sub(r"[^A-Za-z0-9._-]", "_", name).strip("._") or "file"
    return name[:100]


def new_storage_key(request_id: int, filename: str) -> str:
    # Must start with "uploads/": the EC2 IAM policy only allows uploads/* and reports/*.
    return f"uploads/{request_id}/{uuid.uuid4().hex}-{filename}"
