import sqlite3
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from database import Base, User, Kui, Lesson, Progress, Performance

# Connection details
SQLITE_DB_PATH = "kui_db.sqlite"
POSTGRES_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/kui_db")

def migrate_to_postgres():
    if not os.path.exists(SQLITE_DB_PATH):
        print(f"SQLite database not found at {SQLITE_DB_PATH}")
        return

    # 1. Setup PostgreSQL Database and Tables
    pg_engine = create_engine(POSTGRES_URL)
    
    # Drop all existing tables in Postgres to start fresh
    Base.metadata.drop_all(bind=pg_engine)
    # Create all tables with the NEW schema
    Base.metadata.create_all(bind=pg_engine)
    
    PgSession = sessionmaker(bind=pg_engine)
    pg_db = PgSession()

    # 2. Connect to old SQLite database
    sqlite_conn = sqlite3.connect(SQLITE_DB_PATH)
    sqlite_conn.row_factory = sqlite3.Row
    c = sqlite_conn.cursor()

    try:
        # Migrate Users
        print("Migrating users...")
        c.execute("SELECT * FROM users")
        for row in c.fetchall():
            pg_db.add(User(
                id=row["id"],
                username=row["username"],
                email=row["email"],
                hashed_password=row["hashed_password"]
            ))
        pg_db.commit()

        # Migrate existing Kuis
        print("Migrating existing Kuis...")
        c.execute("SELECT * FROM kuis")
        for row in c.fetchall():
            pg_db.add(Kui(
                id=row["id"],
                title=row["title"],
                composer=row["composer"],
                audio_path=row["audio_path"],
                fingerprint=row["fingerprint"],
                is_lesson=bool(row["is_lesson"]),
                level=row["level"]
            ))
        pg_db.commit()

        # Migrate Lessons to the NEW Schema (linking to Kuis)
        print("Migrating lessons and linking to kuis...")
        c.execute("SELECT * FROM lessons")
        for row in c.fetchall():
            # Check if this Kui already exists in Postgres
            kui = pg_db.query(Kui).filter(
                Kui.title == row["title"], 
                Kui.composer == row["composer"]
            ).first()

            if kui:
                kui_id = kui.id
                kui.is_lesson = True
            else:
                # Create the missing Kui entry for this lesson
                new_kui = Kui(
                    title=row["title"],
                    composer=row["composer"],
                    level=row["level"],
                    audio_path=row["audio_path"] or "",
                    is_lesson=True
                )
                pg_db.add(new_kui)
                pg_db.flush() # Get the new ID
                kui_id = new_kui.id

            pg_db.add(Lesson(
                id=row["id"],
                kui_id=kui_id,
                description=row["description"],
                content=row["content"],
                tab_url=row["tab_url"],
                video_url=row["video_url"]
            ))
        pg_db.commit()

        # Migrate User Progress
        print("Migrating user progress...")
        c.execute("SELECT * FROM user_progress")
        for row in c.fetchall():
            pg_db.add(Progress(
                id=row["id"],
                user_id=row["user_id"],
                lesson_id=row["lesson_id"],
                status=row["status"],
                score=row["score"]
            ))
        pg_db.commit()

        # Migrate Performances
        print("Migrating performances...")
        c.execute("SELECT * FROM performances")
        for row in c.fetchall():
            pg_db.add(Performance(
                id=row["id"],
                user_id=row["user_id"],
                lesson_id=row["lesson_id"],
                accuracy=row["accuracy"],
                timing_offset=row["timing_offset"],
                note_consistency=row["note_consistency"],
                final_score=row["final_score"],
                created_at=row["created_at"]
            ))
        pg_db.commit()
        
        # Reset Sequences in PostgreSQL (since we explicitly inserted IDs)
        # Without this, future inserts might throw a UniqueViolation error.
        from sqlalchemy import text
        print("Resetting primary key sequences...")
        tables = ["users", "kuis", "lessons", "user_progress", "performances"]
        for table in tables:
            pg_db.execute(text(f"SELECT setval('{table}_id_seq', COALESCE((SELECT MAX(id) FROM {table}), 1));"))
        pg_db.commit()

        print("Migration to PostgreSQL completed successfully!")

    except Exception as e:
        pg_db.rollback()
        print(f"Migration failed: {e}")
    finally:
        pg_db.close()
        sqlite_conn.close()

if __name__ == "__main__":
    migrate_to_postgres()
