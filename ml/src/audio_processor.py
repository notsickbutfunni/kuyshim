from __future__ import annotations

from dataclasses import dataclass
from io import BytesIO
from typing import Iterable, Tuple

import numpy as np
import soundfile as sf


@dataclass(frozen=True)
class AudioConfig:
    target_sr: int = 44100
    trim_threshold: float = 0.02


def load_audio_from_bytes(data: bytes, config: AudioConfig) -> Tuple[np.ndarray, int]:
    audio, sr = sf.read(BytesIO(data), dtype="float32")
    if audio.ndim > 1:
        audio = np.mean(audio, axis=1)
    if sr != config.target_sr:
        audio = resample_linear(audio, sr, config.target_sr)
        sr = config.target_sr
    audio = normalize(audio)
    audio = trim_silence(audio, threshold=config.trim_threshold)
    return audio, sr


def resample_linear(audio: np.ndarray, sr: int, target_sr: int) -> np.ndarray:
    if len(audio) == 0:
        return audio
    duration = len(audio) / sr
    target_len = int(duration * target_sr)
    if target_len <= 1:
        return audio
    x_old = np.linspace(0.0, 1.0, num=len(audio), endpoint=True)
    x_new = np.linspace(0.0, 1.0, num=target_len, endpoint=True)
    return np.interp(x_new, x_old, audio).astype(np.float32)


def normalize(audio: np.ndarray) -> np.ndarray:
    max_val = np.max(np.abs(audio))
    if max_val < 1e-6:
        return audio
    return (audio / max_val).astype(np.float32)


def trim_silence(audio: np.ndarray, threshold: float) -> np.ndarray:
    if len(audio) == 0:
        return audio
    mask = np.abs(audio) >= threshold
    if not np.any(mask):
        return audio
    
    start = int(np.argmax(mask))
    end = len(audio) - int(np.argmax(mask[::-1]))
    return audio[start:end]


def chunk_audio(audio: np.ndarray, sr: int, chunk_ms: int, hop_ms: int) -> Iterable[np.ndarray]:
    chunk_size = int(sr * chunk_ms / 1000)
    hop_size = int(sr * hop_ms / 1000)
    if chunk_size <= 0 or hop_size <= 0:
        return []
    chunks = []
    for start in range(0, max(1, len(audio) - chunk_size + 1), hop_size):
        chunks.append(audio[start:start + chunk_size])
    return chunks
