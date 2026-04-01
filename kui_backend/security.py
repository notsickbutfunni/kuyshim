from datetime import datetime, timedelta, timezone

import bcrypt
from jose import JWTError, jwt

# ── Настройки JWT ──────────────────────────────────────────────
SECRET_KEY = "CHANGE_ME_TO_A_RANDOM_SECRET"   # замените на надёжный ключ
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60

# ── Хеширование паролей (bcrypt напрямую) ─────────────────────


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Проверяет совпадение открытого пароля с хешем."""
    return bcrypt.checkpw(
        plain_password.encode("utf-8"),
        hashed_password.encode("utf-8"),
    )


def get_password_hash(password: str) -> str:
    """Возвращает bcrypt-хеш пароля."""
    return bcrypt.hashpw(
        password.encode("utf-8"),
        bcrypt.gensalt(),
    ).decode("utf-8")


# ── JWT-токены ────────────────────────────────────────────────
def create_access_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """
    Создаёт JWT-токен.

    Параметры
    ---------
    data : dict
        Полезная нагрузка; обычно {"sub": username_or_email}.
    expires_delta : timedelta | None
        Время жизни токена. Если не указано — ACCESS_TOKEN_EXPIRE_MINUTES.
    """
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (
        expires_delta if expires_delta else timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict | None:
    """
    Декодирует и проверяет JWT-токен.

    Возвращает payload (dict) или None, если токен невалиден / истёк.
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError:
        return None
