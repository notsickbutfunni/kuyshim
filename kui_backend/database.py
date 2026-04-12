from sqlalchemy import (
    Boolean, Column, DateTime, Float, ForeignKey,
    Integer, String, Text, create_engine, func,
)
from sqlalchemy.orm import DeclarativeBase, relationship, sessionmaker
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "sqlite:///./kui_db.sqlite"
)

connect_args = {"check_same_thread": False} if DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(DATABASE_URL, pool_pre_ping=True, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


class Kui(Base):
    __tablename__ = "kuis"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    composer = Column(String, nullable=True)
    audio_path = Column(String, nullable=False)
    fingerprint = Column(Text, nullable=True)
    is_lesson = Column(Boolean, default=False)
    level = Column(String, nullable=True)  # 'beginner' or 'pro'


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)

    progress = relationship("Progress", back_populates="owner")
    performances = relationship("Performance", back_populates="user")


class Lesson(Base):
    __tablename__ = "lessons"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    composer = Column(String, nullable=True)
    level = Column(String)                 # 'beginner' or 'pro'
    description = Column(Text, nullable=True)
    content = Column(Text, nullable=True)  # Текст урока / табы
    audio_path = Column(String, nullable=True)
    tab_url = Column(String, nullable=True)
    video_url = Column(String, nullable=True)

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


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()