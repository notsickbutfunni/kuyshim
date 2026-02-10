import shutil
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, UploadFile, File, Form, Depends
from sqlalchemy.orm import Session
from database import engine, Base, Kui, get_db

# Папка для сохранения файлов
UPLOAD_DIR = "storage/audio"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create all tables on startup
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="KUI Backend", lifespan=lifespan)


@app.get("/")
def root():
    return {"message": "KUI Backend is running"}


@app.get("/health")
def health_check():
    return {"status": "ok"}


@app.post("/kuis/upload")
async def upload_kui(
    title: str = Form(...),
    composer: str = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # 1. Формируем путь к файлу
    file_path = os.path.join(UPLOAD_DIR, file.filename)

    # 2. Сохраняем файл на диск
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 3. Записываем данные в базу (PostgreSQL)
    new_kui = Kui(
        title=title,
        composer=composer,
        audio_path=file_path
    )
    db.add(new_kui)
    db.commit()
    db.refresh(new_kui)

    return {"message": "Кюй успешно загружен", "id": new_kui.id, "path": file_path}