# CloudSound migrations image (alembic + shared db schema)
# Built and pushed by CloudSound repo; used by Helm migrations Job and deploy workflow.
FROM python:3.11-slim

WORKDIR /app

# Install system deps for psycopg2
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy shared requirements and install (includes alembic, psycopg2, sqlalchemy)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy db folder as /app/db (alembic.ini + migrations/)
COPY db /app/db

# Default: run migrations (overridden by Helm Job command)
CMD ["alembic", "upgrade", "head"]
