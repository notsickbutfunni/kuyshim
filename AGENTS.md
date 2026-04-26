# AGENTS.md - Kuyshim Development Guide

## Project Structure

Three-tier system for learning dombra (Kazakh stringed instrument):
- `mobile/` - Flutter app
- `kui_backend/` - FastAPI backend (port 8000)
- `ml/` - Python ML pipeline for pitch/chord detection
- `kui_json/` - Lesson JSON files
- `docs/ARCHITECTURE.md` - Full architecture docs

## Running the Backend

```bash
# Option 1: Docker (requires PostgreSQL)
cd kui_backend && docker-compose up

# Option 2: Local (needs PostgreSQL running)
cd kui_backend
pip install -r requirements.txt
uvicorn main:app --reload
```

## Running ML Tests

```bash
cd ml
pip install -r requirements.txt
pytest tests/
```

## Key Files

| Component | Entry Point |
|-----------|------------|
| Backend API | `kui_backend/main.py` |
| Database models | `kui_backend/database.py` |
| ML inference | `ml/api.py` |
| ML training scripts | `ml/scripts/train_*.py` |

## API Notes

- All API routes under `/api` prefix
- Auth: Bearer token (JWT)
- Login accepts both form-data (`/api/auth/token`) and JSON (`/api/auth/login`)
- Static files served from `/static` mount (`storage/` directory)

## Database

- PostgreSQL via SQLAlchemy 2.0
- Tables: Users, Kui, Lesson, Progress, Performance
- SQLite fallback for dev: `kui_backend/kui_db.sqlite`