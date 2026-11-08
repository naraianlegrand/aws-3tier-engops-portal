FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/src

WORKDIR /app

# Run as a non-root user. The uploads folder is only used for local dev (S3 in AWS).
RUN useradd --create-home --uid 1000 app \
    && mkdir -p /data/uploads \
    && chown app:app /data/uploads

# Dependencies first, so Docker can cache this layer when only the code changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY alembic.ini docker-entrypoint.sh ./
COPY alembic ./alembic
COPY src ./src

USER app
EXPOSE 8000
ENTRYPOINT ["sh", "/app/docker-entrypoint.sh"]
