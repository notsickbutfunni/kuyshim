#!/bin/bash
set -e

echo "⏳ Waiting for database to be ready..."

# Wait for PostgreSQL to accept connections
until python -c "
from sqlalchemy import create_engine, text
import os
engine = create_engine(os.getenv('DATABASE_URL', 'sqlite:///./kui_db.sqlite'))
with engine.connect() as conn:
    conn.execute(text('SELECT 1'))
" 2>/dev/null; do
    echo "  Database not ready yet, retrying in 2s..."
    sleep 2
done

echo "✅ Database is ready!"

# Run seed script (it skips if data already exists)
echo "🌱 Seeding lessons..."
python seed_lessons.py

echo "🚀 Starting FastAPI server..."
exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload
