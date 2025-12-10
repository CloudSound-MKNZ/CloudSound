FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY backend/radio-streaming/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy shared dependencies
COPY backend/shared /app/backend/shared

# Copy service code
COPY backend/radio-streaming/src /app/src

# Set Python path
ENV PYTHONPATH=/app

# Expose port
EXPOSE 8004

# Run the application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8004"]

