"""
sync_storage.py
───────────────
Скрипт синхронизации локальных аудиофайлов с базой данных PostgreSQL.

Сканирует:
  • storage/lessons/beginner  →  is_lesson=True, level='beginner'
  • storage/lessons/pro       →  is_lesson=True, level='pro'
  • storage/all               →  is_lesson=False

Для каждого .mp3 / .wav файла создаётся запись в таблице `kuis`,
если такой audio_path ещё не существует в базе.

Запуск:
    python sync_storage.py
"""

import os
import sys
from pathlib import Path

from database import Base, Kui, SessionLocal, engine

# ── Конфигурация папок ────────────────────────────────────────
SCAN_DIRS = [
    # (путь,               is_lesson,  level)
    ("storage/lessons/beginner", True,  "beginner"),
    ("storage/lessons/pro",      True,  "pro"),
    ("storage/all",              False, None),
]

AUDIO_EXTENSIONS = {".mp3", ".wav"}


def title_from_filename(filename: str) -> str:
    """
    Формирует читаемое название из имени файла.

    Примеры:
        'kui_sary_arka.mp3'  →  'kui sary arka'
        'Sary-Arka.wav'      →  'Sary-Arka'
    """
    stem = Path(filename).stem          # убираем расширение
    return stem.replace("_", " ")       # заменяем _ на пробелы


def sync_folder(
    folder: str,
    is_lesson: bool,
    level: str | None,
    db,
) -> tuple[int, int]:
    """
    Сканирует папку и добавляет новые файлы в БД.

    Возвращает (added, skipped).
    """
    added = 0
    skipped = 0

    folder_path = Path(folder)
    if not folder_path.exists():
        print(f"  ⚠  Папка не найдена, пропускаю: {folder}")
        return added, skipped

    for file in sorted(folder_path.iterdir()):
        if not file.is_file():
            continue
        if file.suffix.lower() not in AUDIO_EXTENSIONS:
            continue

        # Относительный путь для хранения в БД
        relative_path = str(file).replace("\\", "/")

        # Проверяем, есть ли уже в базе
        exists = db.query(Kui).filter(Kui.audio_path == relative_path).first()
        if exists:
            skipped += 1
            continue

        title = title_from_filename(file.name)

        new_kui = Kui(
            title=title,
            audio_path=relative_path,
            is_lesson=is_lesson,
            level=level,
        )
        db.add(new_kui)
        added += 1

    return added, skipped


def main():
    # Создаём таблицы, если ещё не существуют
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    total_added = 0
    total_skipped = 0

    try:
        print("🔄 Синхронизация storage → PostgreSQL\n")

        for folder, is_lesson, level in SCAN_DIRS:
            label = f"{folder}  (is_lesson={is_lesson}, level={level})"
            print(f"📂 {label}")

            added, skipped = sync_folder(folder, is_lesson, level, db)
            total_added += added
            total_skipped += skipped

            print(f"   ✅ добавлено: {added},  ⏭ пропущено (уже есть): {skipped}\n")

        db.commit()

        print("─" * 50)
        print(f"Итого:  ✅ {total_added} новых  |  ⏭ {total_skipped} пропущено")
        print("✔  Синхронизация завершена.")

    except Exception as e:
        db.rollback()
        print(f"\n❌ Ошибка: {e}", file=sys.stderr)
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
