#!/bin/bash
# Setup script for development environment

set -e

echo "🚀 Setting up CloudSound development environment..."

# Check if .env.development exists
if [ ! -f .env.development ]; then
    echo "📝 Creating .env.development from example..."
    cp .env.development.example .env.development
    echo "✅ Created .env.development - please review and customize if needed"
else
    echo "✅ .env.development already exists"
fi

# Set environment variable
export ENVIRONMENT=development

# Start infrastructure
echo "🐳 Starting Docker Compose services..."
# Try docker compose (newer) first, fall back to docker-compose (older)
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    docker compose -f infrastructure/docker/docker-compose.dev.yml up -d
else
    docker-compose -f infrastructure/docker/docker-compose.dev.yml up -d
fi

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Run migrations
echo "🗄️  Running database migrations..."
cd backend/shared/db
alembic upgrade head
cd ../../..

# Seed mock data
echo "🌱 Seeding mock data..."
python scripts/seed-mock-data.py

echo "✅ Development environment setup complete!"
echo ""
echo "Next steps:"
echo "  1. Start services: cd backend/<service> && uvicorn src.main:app --reload"
echo "  2. Start frontend: cd frontend && npm run dev"
echo "  3. Access services:"
echo "     - API Gateway: http://localhost:8000"
echo "     - RabbitMQ Management: http://localhost:15672"
echo "     - MinIO Console: http://localhost:9001"

