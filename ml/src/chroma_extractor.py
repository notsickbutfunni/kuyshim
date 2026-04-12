from __future__ import annotations

from dataclasses import dataclass
from typing import Tuple

import librosa
import numpy as np


@dataclass(frozen=True)
class ChromaConfig:
    n_chroma: int = 24
    hop_length: int = 512
    n_octaves: int = 7
    target_frames: int = 87


def compute_chroma_from_audio(audio: np.ndarray, sr: int, config: ChromaConfig) -> np.ndarray:
    chroma = librosa.feature.chroma_cqt(
        y=audio,
        sr=sr,
        hop_length=config.hop_length,
        n_chroma=config.n_chroma,
        bins_per_octave=config.n_chroma,
        n_octaves=config.n_octaves,
    )
    return _pad_or_trim(chroma, config.target_frames)


def compute_chroma_from_file(path: str, config: ChromaConfig, duration: float | None = 2.0) -> Tuple[np.ndarray, int]:
    audio, sr = librosa.load(path, duration=duration, mono=True)
    chroma = compute_chroma_from_audio(audio, sr, config)
    return chroma, sr


def _pad_or_trim(chroma: np.ndarray, target_frames: int) -> np.ndarray:
    if chroma.shape[1] == target_frames:
        return chroma.astype(np.float32)

    if chroma.shape[1] > target_frames:
        return chroma[:, :target_frames].astype(np.float32)

    pad_width = target_frames - chroma.shape[1]
    pad = np.zeros((chroma.shape[0], pad_width), dtype=np.float32)
    return np.concatenate([chroma.astype(np.float32), pad], axis=1)
