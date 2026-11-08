#!/bin/sh
# Container start: bring the DB schema up to date, then start the web server.
# Known limitation: with 2+ instances starting together, each runs migrations.
# Fine for this project (ASG min 1); production would run migrations as a separate CI/CD step.
set -e
alembic upgrade head
exec uvicorn engops.main:create_app --factory --host 0.0.0.0 --port 8000
