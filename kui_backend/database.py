from sqlalchemy import (
    Boolean, Column, DateTime, Float, ForeignKey,
    Integer, String, Text, create_engine, func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, relationship, sessionmaker
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg://user:password@localhost:5432/kui_db"
)

# Upgrade URL to use psycopg3 driver if it just says postgresql://
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(
    DATABASE_URL, 
    pool_pre_ping=True, 
    pool_size=10, 
    max_overflow=20,
    connect_args=connect_args
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


class Kui(Base):
    __tablename__ = "kuis"

    id = Column(Integer, primary_key=True, index=True)
    title_translations = Column(JSONB, nullable=False, server_default='{}')
    artist_translations = Column(JSONB, nullable=False, server_default='{}')
    audio_url = Column(Text, nullable=False)
    image_url = Column(Text, nullable=False)
    json_file = Column(String, nullable=False)
    duration = Column(Float, nullable=False)
    bpm = Column(Float, nullable=False)
    total_notes = Column(Integer, nullable=False)
    difficulty = Column(String, nullable=False)

    lessons = relationship("Lesson", back_populates="kui")


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    avatar_url = Column(String, nullable=True)

    progress = relationship("Progress", back_populates="owner")
    performances = relationship("Performance", back_populates="user")
    tuner_results = relationship("TunerResult", back_populates="user")
    achievements = relationship("UserAchievement", back_populates="user")


class Lesson(Base):
    __tablename__ = "lessons"
    id = Column(Integer, primary_key=True, index=True)
    kui_id = Column(Integer, ForeignKey("kuis.id"))
    
    description = Column(Text, nullable=True)
    content = Column(Text, nullable=True)  # Текст урока / табы
    tab_url = Column(String, nullable=True)
    video_url = Column(String, nullable=True)

    kui = relationship("Kui", back_populates="lessons")
    progress = relationship("Progress", back_populates="lesson")
    performances = relationship("Performance", back_populates="lesson")


class Progress(Base):
    __tablename__ = "user_progress"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    lesson_id = Column(Integer, ForeignKey("lessons.id"))
    status = Column(String, default="started")  # started, completed
    score = Column(Integer, nullable=True)

    owner = relationship("User", back_populates="progress")
    lesson = relationship("Lesson", back_populates="progress")


class Performance(Base):
    __tablename__ = "performances"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    lesson_id = Column(Integer, ForeignKey("lessons.id"))
    accuracy = Column(Float, nullable=False)
    timing_offset = Column(Float, nullable=False)
    note_consistency = Column(Float, nullable=False)
    final_score = Column(Float, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="performances")
    lesson = relationship("Lesson", back_populates="performances")


class TunerResult(Base):
    """Stores ML chord recognition results from the tuner screen."""
    __tablename__ = "tuner_results"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    predicted_class = Column(String, nullable=False)
    confidence = Column(Float, nullable=False)
    top_5_json = Column(Text, nullable=True)  # JSON string of top 5 predictions
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="tuner_results")


class UserAchievement(Base):
    """Stores permanently unlocked achievements for users."""
    __tablename__ = "user_achievements"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    achievement_key = Column(String, nullable=False)
    unlocked_at = Column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="achievements")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()