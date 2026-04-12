"""
audio_processor.py
──────────────────
Модуль для предобработки аудиофайлов перед подачей в ML-модели.
Использует FFmpeg через subprocess для конвертации в стандартный формат:
WAV, 16 000 Hz, Mono, 16-bit PCM.
"""

import os
import subprocess
from pathlib import Path


class AudioProcessingError(Exception):
    """Базовое исключение для ошибок обработки аудио."""


class FFmpegNotFoundError(AudioProcessingError):
    """FFmpeg не найден в системе."""


class CorruptedFileError(AudioProcessingError):
    """Входной файл повреждён или имеет неподдерживаемый формат."""


def process_audio_for_ml(input_path: str) -> str:
    """
    Конвертирует аудиофайл в формат, пригодный для ML-моделей.

    Выходной формат: WAV, 16 000 Hz, Mono, 16-bit PCM (s16le).

    Параметры
    ---------
    input_path : str
        Путь к исходному аудиофайлу (mp3, ogg, m4a, wav и т.д.).

    Возвращает
    ----------
    str
        Абсолютный путь к обработанному .wav файлу.

    Исключения
    ----------
    FileNotFoundError
        Если входной файл не существует.
    FFmpegNotFoundError
        Если FFmpeg не установлен или недоступен в PATH.
    CorruptedFileError
        Если файл повреждён или FFmpeg не может его обработать.
    """

    input_file = Path(input_path)

    # ── Проверяем, что файл существует ────────────────────────
    if not input_file.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")

    # ── Формируем путь для выходного файла ────────────────────
    output_file = input_file.with_suffix(".ml.wav")

    # ── Команда FFmpeg ────────────────────────────────────────
    # -y             : перезаписать, если существует
    # -i             : входной файл
    # -ar 16000      : частота дискретизации 16 кГц
    # -ac 1          : моно
    # -sample_fmt s16: 16-bit PCM
    # -f wav         : формат выходного файла
    command = [
        "ffmpeg",
        "-y",
        "-i", str(input_file),
        "-ar", "16000",
        "-ac", "1",
        "-sample_fmt", "s16",
        "-f", "wav",
        str(output_file),
    ]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=120,  # таймаут 2 минуты на случай зависания
        )
    except FileNotFoundError:
        raise FFmpegNotFoundError(
            "FFmpeg is not installed or not found in PATH. "
            "Install it with: apt-get install ffmpeg"
        )
    except subprocess.TimeoutExpired:
        raise AudioProcessingError(
            f"FFmpeg timed out while processing: {input_path}"
        )

    # ── Проверяем результат ───────────────────────────────────
    if result.returncode != 0:
        stderr = result.stderr.strip()
        raise CorruptedFileError(
            f"FFmpeg failed (code {result.returncode}) for '{input_path}'.\n"
            f"stderr: {stderr}"
        )

    if not output_file.exists() or output_file.stat().st_size == 0:
        raise CorruptedFileError(
            f"FFmpeg produced an empty or missing output for: {input_path}"
        )

    return str(output_file.resolve())
