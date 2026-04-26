import shutil
import os
import uuid
from contextlib import asynccontextmanager

from fastapi import FastAPI, APIRouter, UploadFile, File, Form, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session
from typing import List, Optional

from database import engine, Base, Kui, User, Lesson, Progress, Performance, TunerResult, get_db
from security import verify_password, get_password_hash, create_access_token, decode_access_token

# ── OAuth2-схема: указывает клиенту, куда слать логин ────────
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)

# Папка для сохранения файлов
UPLOAD_DIR = "storage/audio"
os.makedirs(UPLOAD_DIR, exist_ok=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create all tables on startup
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="KUI Backend", lifespan=lifespan)

# ── API Router — all endpoints under /api prefix ─────────────
api = APIRouter(prefix="/api")

# ── CORS ─────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Монтируем папку со звуками, чтобы они были доступны в браузере/флаттере
# Файл доступен по ссылке: http://localhost:8000/static/audio/filename.mp3
app.mount("/static", StaticFiles(directory="storage"), name="static")


# ── Зависимость: текущий пользователь из JWT ─────────────────
async def get_current_user(
    request: Request,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Извлекает пользователя из Bearer-токена. Возвращает 401, если токен невалиден."""
    # Support both OAuth2 header and manual Authorization header
    if token is None:
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            token = auth_header[7:]
        else:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated",
                headers={"WWW-Authenticate": "Bearer"},
            )

    payload = decode_access_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    username: str | None = payload.get("sub")
    if username is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload missing 'sub'",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


@app.get("/")
def root():
    return {"message": "KUI Backend is running"}



@app.get("/health")
@api.get("/health")
def health_check():
    return {"status": "ok"}


# ── User profile ─────────────────────────────────────────────
@api.get("/users/me")
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
):
    """Return the authenticated user's profile."""
    return {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
        "level": 1,
        "rank": "Student",
        "avatar_url": None,
        "total_practice": "0h",
        "mastery_score": 0,
        "streak_days": 0,
    }


@api.post("/kuis/upload")
async def upload_kui(
    title: str = Form(...),
    artist: str = Form("Unknown"),
    difficulty: str = Form("beginner"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db)
):
    # 1. Создаем уникальное имя, чтобы файлы не перезаписывались
    file_extension = os.path.splitext(file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    file_path = os.path.join(UPLOAD_DIR, unique_filename)

    # 2. Сохраняем файл на диск
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    # 3. Записываем данные в базу (PostgreSQL) — храним только имя файла
    new_kui = Kui(
        title=title,
        artist=artist,
        audio_url=f"/static/audio/{unique_filename}",
        image_url="",
        json_file="",
        duration=0.0,
        bpm=0.0,
        total_notes=0,
        difficulty=difficulty
    )
    db.add(new_kui)
    db.commit()
    db.refresh(new_kui)

    # Возвращаем полный URL для фронтенда
    return {
        "id": new_kui.id,
        "title": new_kui.title,
        "url": f"http://localhost:8000{new_kui.audio_url}"
    }


# ── Схемы для аутентификации ──────────────────────────────────
class RegisterRequest(BaseModel):
    username: str
    email: EmailStr
    password: str


class ResetPasswordRequest(BaseModel):
    username: str
    email: EmailStr
    new_password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class KuiOut(BaseModel):
    id: int
    title: str
    artist: str
    audio_url: str
    image_url: str
    json_file: str
    duration: float
    bpm: float
    total_notes: int
    difficulty: str


class LessonOut(BaseModel):
    id: int
    title: str
    artist: Optional[str] = None
    difficulty: Optional[str] = None
    description: Optional[str] = None
    content: Optional[str] = None
    audio_url: Optional[str] = None
    tab_url: Optional[str] = None
    video_url: Optional[str] = None
    progress_status: Optional[str] = None


class ProgressIn(BaseModel):
    status: str  # "started" or "completed"


class ScoreIn(BaseModel):
    accuracy: float
    timing_offset: float
    note_consistency: float


class PerformanceOut(BaseModel):
    id: int
    accuracy: float
    timing_offset: float
    note_consistency: float
    final_score: float
    created_at: Optional[str] = None


# ── Аутентификация ────────────────────────────────────────────
@api.post("/auth/register", status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    """Регистрация нового пользователя."""

    # Проверяем, не занят ли username
    if db.query(User).filter(User.username == body.username).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username already taken",
        )

    # Проверяем, не занят ли email
    if db.query(User).filter(User.email == body.email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    try:
        new_user = User(
            username=body.username,
            email=body.email,
            hashed_password=get_password_hash(body.password),
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        return {"id": new_user.id, "username": new_user.username, "email": new_user.email}
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed due to a server error. Please try again later.",
        )


@api.post("/auth/reset-password")
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)):
    """Reset password by verifying username + email combination."""

    user = (
        db.query(User)
        .filter(User.username == body.username, User.email == body.email)
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with that username and email combination",
        )

    user.hashed_password = get_password_hash(body.new_password)
    db.commit()

    return {"message": "Password reset successfully"}


# ── Login schema for JSON body ────────────────────────────────
class LoginRequest(BaseModel):
    username: str
    password: str


@api.post("/auth/token", response_model=TokenResponse)
def login_form(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """OAuth2-compatible login via form-data."""
    user = (
        db.query(User)
        .filter((User.username == form.username) | (User.email == form.username))
        .first()
    )
    if not user or not verify_password(form.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token(data={"sub": user.username})
    return {"access_token": token, "token_type": "bearer"}


@api.post("/auth/login", response_model=TokenResponse)
def login_json(body: LoginRequest, db: Session = Depends(get_db)):
    """Авторизация через JSON (used by Flutter). Also accepts form-data at /auth/token."""
    user = (
        db.query(User)
        .filter((User.username == body.username) | (User.email == body.username))
        .first()
    )
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = create_access_token(data={"sub": user.username})
    return {"access_token": token, "token_type": "bearer"}


@api.get("/kuis", response_model=List[KuiOut])
def get_all_kuis(db: Session = Depends(get_db)):
    """Fetch all kuis and their CDN/download links for the mobile client."""
    kuis = db.query(Kui).all()
    return [
        KuiOut(
            id=k.id,
            title=k.title,
            artist=k.artist,
            audio_url=k.audio_url,
            image_url=k.image_url,
            json_file=k.json_file,
            duration=k.duration,
            bpm=k.bpm,
            total_notes=k.total_notes,
            difficulty=k.difficulty,
        )
        for k in kuis
    ]

# ── Защищённые эндпоинты (требуют Bearer-токен) ──────────────
@api.get("/kuis/play", response_model=List[KuiOut])
def get_kuis_for_play(
    level: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Возвращает список кюев с URL аудиофайлов.
    Только для авторизованных пользователей.

    Query-параметры:
        level — 'beginner', 'pro' или не указан (все).
    """
    query = db.query(Kui)

    if level is not None:
        query = query.filter(Kui.difficulty == level)

    kuis = query.all()

    return [
        KuiOut(
            id=k.id,
            title=k.title,
            artist=k.artist,
            audio_url=k.audio_url,
            image_url=k.image_url,
            json_file=k.json_file,
            duration=k.duration,
            bpm=k.bpm,
            total_notes=k.total_notes,
            difficulty=k.difficulty,
        )
        for k in kuis
    ]


# ── Lesson endpoints (require Bearer token) ──────────────────

@api.get("/lessons", response_model=List[LessonOut])
def list_lessons(
    level: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List lessons, optionally filtered by level. Includes user's progress status."""
    query = db.query(Lesson).join(Lesson.kui)
    if level:
        query = query.filter(Kui.level == level)
    lessons = query.all()

    result = []
    for les in lessons:
        prog = (
            db.query(Progress)
            .filter(Progress.user_id == current_user.id, Progress.lesson_id == les.id)
            .first()
        )
        result.append(LessonOut(
            id=les.id,
            title=les.kui.title if les.kui else "Unknown",
            artist=les.kui.artist if les.kui else None,
            difficulty=les.kui.difficulty if les.kui else None,
            description=les.description,
            content=les.content,
            audio_url=les.kui.audio_url if les.kui else None,
            tab_url=les.tab_url,
            video_url=les.video_url,
            progress_status=prog.status if prog else None,
        ))
    return result


@api.get("/lessons/{lesson_id}", response_model=LessonOut)
def get_lesson(
    lesson_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get a single lesson by ID, including user's progress status."""
    les = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not les:
        raise HTTPException(status_code=404, detail="Lesson not found")

    prog = (
        db.query(Progress)
        .filter(Progress.user_id == current_user.id, Progress.lesson_id == les.id)
        .first()
    )
    return LessonOut(
        id=les.id,
        title=les.kui.title if les.kui else "Unknown",
        artist=les.kui.artist if les.kui else None,
        difficulty=les.kui.difficulty if les.kui else None,
        description=les.description,
        content=les.content,
        audio_url=les.kui.audio_url if les.kui else None,
        tab_url=les.tab_url,
        video_url=les.video_url,
        progress_status=prog.status if prog else None,
    )


@api.post("/lessons/{lesson_id}/progress")
def update_progress(
    lesson_id: int,
    body: ProgressIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create or update progress for a lesson (started / completed)."""
    les = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not les:
        raise HTTPException(status_code=404, detail="Lesson not found")

    if body.status not in ("started", "completed"):
        raise HTTPException(status_code=400, detail="Status must be 'started' or 'completed'")

    prog = (
        db.query(Progress)
        .filter(Progress.user_id == current_user.id, Progress.lesson_id == lesson_id)
        .first()
    )
    if prog:
        prog.status = body.status
    else:
        prog = Progress(user_id=current_user.id, lesson_id=lesson_id, status=body.status)
        db.add(prog)

    db.commit()
    db.refresh(prog)
    return {"id": prog.id, "lesson_id": lesson_id, "status": prog.status}


@api.post("/lessons/{lesson_id}/score")
def submit_score(
    lesson_id: int,
    body: ScoreIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Receive ML payload, calculate final score, and store in performances.
    Formula: final_score = (accuracy * 0.5) + ((100 - timing_offset) * 0.3) + (note_consistency * 0.2)
    """
    les = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not les:
        raise HTTPException(status_code=404, detail="Lesson not found")

    final_score = (
        (body.accuracy * 0.5)
        + ((100 - body.timing_offset) * 0.3)
        + (body.note_consistency * 0.2)
    )

    perf = Performance(
        user_id=current_user.id,
        lesson_id=lesson_id,
        accuracy=body.accuracy,
        timing_offset=body.timing_offset,
        note_consistency=body.note_consistency,
        final_score=round(final_score, 2),
    )
    db.add(perf)
    db.commit()
    db.refresh(perf)

    return {
        "id": perf.id,
        "lesson_id": lesson_id,
        "final_score": perf.final_score,
        "accuracy": perf.accuracy,
        "timing_offset": perf.timing_offset,
        "note_consistency": perf.note_consistency,
    }


@api.get("/lessons/{lesson_id}/performances", response_model=List[PerformanceOut])
def get_performances(
    lesson_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return user's performance history for a specific lesson."""
    perfs = (
        db.query(Performance)
        .filter(Performance.user_id == current_user.id, Performance.lesson_id == lesson_id)
        .order_by(Performance.created_at.desc())
        .all()
    )
    return [
        PerformanceOut(
            id=p.id,
            accuracy=p.accuracy,
            timing_offset=p.timing_offset,
            note_consistency=p.note_consistency,
            final_score=p.final_score,
            created_at=str(p.created_at) if p.created_at else None,
        )
        for p in perfs
    ]


# ── Tuner Results ─────────────────────────────────────────────
import json as json_lib

class TunerResultIn(BaseModel):
    predicted_class: str
    confidence: float
    top_5: Optional[dict] = None

class TunerResultOut(BaseModel):
    id: int
    predicted_class: str
    confidence: float
    top_5: Optional[dict] = None
    created_at: Optional[str] = None

@api.post("/tuner/result", response_model=TunerResultOut)
async def save_tuner_result(
    body: TunerResultIn,
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    """Save a chord recognition result for the authenticated user."""
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = db.query(User).filter(User.username == payload.get("sub")).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    result = TunerResult(
        user_id=user.id,
        predicted_class=body.predicted_class,
        confidence=body.confidence,
        top_5_json=json_lib.dumps(body.top_5) if body.top_5 else None,
    )
    db.add(result)
    db.commit()
    db.refresh(result)

    return TunerResultOut(
        id=result.id,
        predicted_class=result.predicted_class,
        confidence=result.confidence,
        top_5=body.top_5,
        created_at=str(result.created_at) if result.created_at else None,
    )

@api.get("/tuner/results", response_model=List[TunerResultOut])
async def get_tuner_results(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
):
    """Fetch the authenticated user's tuner recognition history."""
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    payload = decode_access_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Invalid token")
    user = db.query(User).filter(User.username == payload.get("sub")).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    results = (
        db.query(TunerResult)
        .filter(TunerResult.user_id == user.id)
        .order_by(TunerResult.created_at.desc())
        .limit(50)
        .all()
    )

    out = []
    for r in results:
        top5 = None
        if r.top_5_json:
            try:
                top5 = json_lib.loads(r.top_5_json)
            except Exception:
                pass
        out.append(TunerResultOut(
            id=r.id,
            predicted_class=r.predicted_class,
            confidence=r.confidence,
            top_5=top5,
            created_at=str(r.created_at) if r.created_at else None,
        ))
    return out


# ── Register the API router with the main app ────────────────
app.include_router(api)