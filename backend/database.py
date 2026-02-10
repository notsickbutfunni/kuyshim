from sqlalchemy import Column, Integer, String, Text, create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://user:password@db:5432/kui_db"
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


class Kui(Base):
    __tablename__ = "kuis"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)        # Название кюя
    composer = Column(String, nullable=True)      # Автор
    audio_path = Column(String, nullable=False)   # Путь к MP3/WAV файлу
    fingerprint = Column(Text, nullable=True)     # Хеш для ML (Шазама)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()