import shutil
import os
import uuid
import httpx
from contextlib import asynccontextmanager

from fastapi import FastAPI, UploadFile, File, Form, Depends, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func as sa_func
from typing import List, Optional

from database import engine, Base, Kui, User, Lesson, Progress, Performance, get_db
from security import verify_password, get_password_hash, create_access_token, decode_access_token

# ── OAuth2-схема: указывает клиенту, куда слать логин ────────
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# Папка для сохранения файлов
UPLOAD_DIR = "storage/audio"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# ── ML Service URL ───────────────────────────────────────────
ML_SERVICE_URL = os.getenv("ML_SERVICE_URL", "http://ml:8001")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create all tables on startup
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="KUI Backend", lifespan=lifespan)

# ── CORS ─────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://127.0.0.1:3000", "http://localhost:8080", "http://10.0.2.2:8000", "*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Монтируем папку со звуками, чтобы они были доступны в браузере/флаттере
# Файл доступен по ссылке: http://localhost:8000/static/audio/filename.mp3
app.mount("/static", StaticFiles(directory="storage"), name="static")


# ── Зависимость: текущий пользователь из JWT ─────────────────
def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """Извлекает пользователя из Bearer-токена. Возвращает 401, если токен невалиден."""
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
def health_check():
    return {"status": "ok"}


@app.get("/ml/health")
async def ml_health_check():
    """Proxy ML service health check so the frontend can query it via the backend."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(f"{ML_SERVICE_URL}/health")
            if response.status_code == 200:
                return response.json()
            return {"status": "unavailable", "model_loaded": False}
    except Exception:
        return {"status": "unavailable", "model_loaded": False}


@app.post("/kuis/upload")
async def upload_kui(
    title: str = Form(...),
    composer: str = Form(None),
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
        composer=composer,
        audio_path=unique_filename
    )
    db.add(new_kui)
    db.commit()
    db.refresh(new_kui)

    # Возвращаем полный URL для фронтенда
    return {
        "id": new_kui.id,
        "title": new_kui.title,
        "url": f"http://localhost:8000/static/audio/{unique_filename}"
    }


# ── Схемы для аутентификации ──────────────────────────────────
class RegisterRequest(BaseModel):
    username: str
    email: str
    password: str


class ResetPasswordRequest(BaseModel):
    username: str
    email: str
    new_password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class KuiOut(BaseModel):
    id: int
    title: str
    composer: Optional[str] = None
    audio_url: str
    is_lesson: bool = False
    level: Optional[str] = None


class LessonOut(BaseModel):
    id: int
    title: str
    composer: Optional[str] = None
    level: Optional[str] = None
    description: Optional[str] = None
    content: Optional[str] = None
    audio_path: Optional[str] = None
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

class UserProfile(BaseModel):
    id: int
    username: str
    email: str


class UserStatsOut(BaseModel):
    total_performances: int
    total_lessons_played: int
    lessons_completed: int
    avg_accuracy: Optional[float] = None
    avg_timing_offset: Optional[float] = None
    avg_note_consistency: Optional[float] = None
    avg_final_score: Optional[float] = None
    best_score: Optional[float] = None
    total_practice_hours: float
    current_streak: int


# ── User Profile Endpoints ────────────────────────────────────
@app.get("/users/me", response_model=UserProfile)
def get_current_user_profile(
    current_user: User = Depends(get_current_user),
):
    """Return the authenticated user's profile."""
    return UserProfile(
        id=current_user.id,
        username=current_user.username,
        email=current_user.email,
    )


@app.get("/users/me/stats", response_model=UserStatsOut)
def get_user_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Aggregate user stats from performance history and progress."""
    # Count total performances
    total_performances = (
        db.query(sa_func.count(Performance.id))
        .filter(Performance.user_id == current_user.id)
        .scalar()
    ) or 0

    # Count distinct lessons played
    total_lessons_played = (
        db.query(sa_func.count(sa_func.distinct(Performance.lesson_id)))
        .filter(Performance.user_id == current_user.id)
        .scalar()
    ) or 0

    # Count completed lessons
    lessons_completed = (
        db.query(sa_func.count(Progress.id))
        .filter(Progress.user_id == current_user.id, Progress.status == "completed")
        .scalar()
    ) or 0

    # Average metrics across all performances
    avg_accuracy = (
        db.query(sa_func.avg(Performance.accuracy))
        .filter(Performance.user_id == current_user.id)
        .scalar()
    )
    avg_timing_offset = (
        db.query(sa_func.avg(Performance.timing_offset))
        .filter(Performance.user_id == current_user.id)
        .scalar()
    )
    avg_note_consistency = (
        db.query(sa_func.avg(Performance.note_consistency))
        .filter(Performance.user_id == current_user.id)
        .scalar()
    )
    avg_final_score = (
        db.query(sa_func.avg(Performance.final_score))
        .filter(Performance.user_id == current_user.id)
        .scalar()
    )
    best_score = (
        db.query(sa_func.max(Performance.final_score))
        .filter(Performance.user_id == current_user.id)
        .scalar()
    )

    # Estimate practice hours (assume ~3 min per performance)
    total_practice_hours = round(total_performances * 3.0 / 60.0, 1)

    # Simple streak: count consecutive days with performances (simplified)
    current_streak = min(total_performances, 7)  # simplified streak calc

    return UserStatsOut(
        total_performances=total_performances,
        total_lessons_played=total_lessons_played,
        lessons_completed=lessons_completed,
        avg_accuracy=round(avg_accuracy, 1) if avg_accuracy else None,
        avg_timing_offset=round(avg_timing_offset, 1) if avg_timing_offset else None,
        avg_note_consistency=round(avg_note_consistency, 1) if avg_note_consistency else None,
        avg_final_score=round(avg_final_score, 1) if avg_final_score else None,
        best_score=round(best_score, 1) if best_score else None,
        total_practice_hours=total_practice_hours,
        current_streak=current_streak,
    )


# ── Аутентификация ────────────────────────────────────────────
@app.post("/auth/register", status_code=status.HTTP_201_CREATED)
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

    new_user = User(
        username=body.username,
        email=body.email,
        hashed_password=get_password_hash(body.password),
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {"id": new_user.id, "username": new_user.username, "email": new_user.email}


@app.post("/auth/reset-password")
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


@app.post("/auth/token", response_model=TokenResponse)
@app.post("/auth/login", response_model=TokenResponse)
def login(form: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """Авторизация — возвращает JWT-токен. Доступен по /auth/token и /auth/login."""

    # OAuth2PasswordRequestForm передаёт поле `username`,
    # но пользователь может ввести туда и email
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


# ── Защищённые эндпоинты (требуют Bearer-токен) ──────────────
@app.get("/kuis/play", response_model=List[KuiOut])
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
        query = query.filter(Kui.level == level)

    kuis = query.all()

    return [
        KuiOut(
            id=k.id,
            title=k.title,
            composer=k.composer,
            audio_url=f"/static/audio/{k.audio_path}",
            is_lesson=k.is_lesson or False,
            level=k.level,
        )
        for k in kuis
    ]


# ── Lesson endpoints (require Bearer token) ──────────────────

@app.get("/lessons", response_model=List[LessonOut])
def list_lessons(
    level: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List lessons, optionally filtered by level. Includes user's progress status."""
    query = db.query(Lesson)
    if level:
        query = query.filter(Lesson.level == level)
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
            title=les.title,
            composer=les.composer,
            level=les.level,
            description=les.description,
            content=les.content,
            audio_path=les.audio_path,
            tab_url=les.tab_url,
            video_url=les.video_url,
            progress_status=prog.status if prog else None,
        ))
    return result


@app.get("/lessons/{lesson_id}", response_model=LessonOut)
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
        title=les.title,
        composer=les.composer,
        level=les.level,
        description=les.description,
        content=les.content,
        audio_path=les.audio_path,
        tab_url=les.tab_url,
        video_url=les.video_url,
        progress_status=prog.status if prog else None,
    )


@app.post("/lessons/{lesson_id}/progress")
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


@app.post("/lessons/{lesson_id}/score")
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


@app.get("/lessons/{lesson_id}/performances", response_model=List[PerformanceOut])
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


# ── ML-powered audio analysis ────────────────────────────────────
class AnalyzeResponse(BaseModel):
    lesson_id: int
    accuracy: float
    timing_offset: float
    note_consistency: float
    final_score: float
    predicted_chord: Optional[str] = None
    reference_chord: Optional[str] = None
    performance_id: int


@app.post("/lessons/{lesson_id}/analyze", response_model=AnalyzeResponse)
async def analyze_performance(
    lesson_id: int,
    audio: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Upload user audio for ML-powered performance analysis.

    Sends the user audio + lesson reference audio to the ML service,
    which returns accuracy, timing, and consistency scores.
    Results are stored as a Performance record.
    """
    # 1. Verify lesson exists
    les = db.query(Lesson).filter(Lesson.id == lesson_id).first()
    if not les:
        raise HTTPException(status_code=404, detail="Lesson not found")

    # 2. Read user audio
    user_audio_bytes = await audio.read()
    if len(user_audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

    # 3. Save user audio to storage
    file_ext = os.path.splitext(audio.filename or "recording.wav")[1] or ".wav"
    unique_name = f"{uuid.uuid4()}{file_ext}"
    user_audio_path = os.path.join(UPLOAD_DIR, unique_name)
    with open(user_audio_path, "wb") as f:
        f.write(user_audio_bytes)

    # 4. Load reference audio (from lesson)
    ref_audio_bytes = None
    if les.audio_path:
        # Try multiple possible locations for the reference audio
        possible_paths = [
            os.path.join("storage", "audio", les.audio_path),
            os.path.join("storage", "lessons", les.audio_path),
            os.path.join("storage", les.audio_path),
            les.audio_path,
        ]
        for ref_path in possible_paths:
            if os.path.exists(ref_path):
                with open(ref_path, "rb") as f:
                    ref_audio_bytes = f.read()
                break

    # 5. Call ML service
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            if ref_audio_bytes:
                # Full evaluation: compare user vs reference
                response = await client.post(
                    f"{ML_SERVICE_URL}/evaluate",
                    files={
                        "user_audio": ("user_audio.wav", user_audio_bytes, "audio/wav"),
                        "reference_audio": ("reference.wav", ref_audio_bytes, "audio/wav"),
                    },
                )
            else:
                # Prediction only (no reference audio available)
                response = await client.post(
                    f"{ML_SERVICE_URL}/predict",
                    files={"audio": ("audio.wav", user_audio_bytes, "audio/wav")},
                )

        if response.status_code != 200:
            raise HTTPException(
                status_code=502,
                detail=f"ML service error: {response.text}",
            )

        ml_result = response.json()

    except httpx.ConnectError:
        raise HTTPException(
            status_code=503,
            detail="ML service is unavailable. Make sure it is running.",
        )
    except httpx.TimeoutException:
        raise HTTPException(
            status_code=504,
            detail="ML service timed out during analysis.",
        )

    # 6. Extract scores from ML response
    if ref_audio_bytes:
        accuracy = ml_result.get("accuracy", 0.0)
        timing_offset = ml_result.get("timing_offset", 0.0)
        note_consistency = ml_result.get("note_consistency", 0.0)
        final_score = ml_result.get("final_score", 0.0)
        predicted_chord = ml_result.get("predicted_chord")
        reference_chord = ml_result.get("reference_chord")
    else:
        # Only prediction available, generate approximate scores
        accuracy = ml_result.get("confidence", 0.0) * 100
        timing_offset = 0.0
        note_consistency = accuracy * 0.8
        final_score = (accuracy * 0.5) + (100 * 0.3) + (note_consistency * 0.2)
        predicted_chord = ml_result.get("predicted_class")
        reference_chord = None

    # 7. Store performance in DB
    perf = Performance(
        user_id=current_user.id,
        lesson_id=lesson_id,
        accuracy=round(accuracy, 2),
        timing_offset=round(timing_offset, 2),
        note_consistency=round(note_consistency, 2),
        final_score=round(final_score, 2),
    )
    db.add(perf)
    db.commit()
    db.refresh(perf)

    # 8. Auto-update progress to "started" if not already
    prog = (
        db.query(Progress)
        .filter(Progress.user_id == current_user.id, Progress.lesson_id == lesson_id)
        .first()
    )
    if not prog:
        prog = Progress(user_id=current_user.id, lesson_id=lesson_id, status="started")
        db.add(prog)
        db.commit()

    return AnalyzeResponse(
        lesson_id=lesson_id,
        accuracy=perf.accuracy,
        timing_offset=perf.timing_offset,
        note_consistency=perf.note_consistency,
        final_score=perf.final_score,
        predicted_chord=predicted_chord,
        reference_chord=reference_chord,
        performance_id=perf.id,
    )