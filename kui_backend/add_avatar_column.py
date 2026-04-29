import os
from sqlalchemy import text
from database import engine

def migrate():
    with engine.connect() as conn:
        try:
            # Check if using SQLite
            if engine.url.drivername == 'sqlite':
                conn.execute(text("ALTER TABLE users ADD COLUMN avatar_url VARCHAR;"))
            else:
                conn.execute(text("ALTER TABLE users ADD COLUMN avatar_url VARCHAR;"))
            
            conn.commit()
            print("Successfully added avatar_url column to users table.")
        except Exception as e:
            if "duplicate column name" in str(e) or "already exists" in str(e):
                print("Column avatar_url already exists.")
            else:
                print(f"Error during migration: {e}")

if __name__ == "__main__":
    migrate()
