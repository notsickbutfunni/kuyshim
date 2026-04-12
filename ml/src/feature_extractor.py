from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Tuple

import numpy as np


@dataclass(frozen=True)
class FeatureConfig:
    frame_ms: int = 25
    hop_ms: int = 10
    rolloff_percent: float = 0.85


def frame_audio(audio: np.ndarray, sr: int, frame_ms: int, hop_ms: int) -> np.ndarray:
    frame_size = int(sr * frame_ms / 1000)
    hop_size = int(sr * hop_ms / 1000)
    if frame_size <= 0 or hop_size <= 0:
        return np.empty((0, 0), dtype=np.float32)

    num_frames = 1 + max(0, (len(audio) - frame_size) // hop_size)
    frames = np.zeros((num_frames, frame_size), dtype=np.float32)

    for i in range(num_frames):
        start = i * hop_size
        end = start + frame_size
        frames[i] = audio[start:end]

    return frames


def zero_crossing_rate(frames: np.ndarray) -> np.ndarray:
    if frames.size == 0:
        return np.array([], dtype=np.float32)
    signs = np.sign(frames)
    signs[signs == 0] = -1
    zcr = np.mean(signs[:, 1:] != signs[:, :-1], axis=1)
    return zcr.astype(np.float32)


def rms_energy(frames: np.ndarray) -> np.ndarray:
    if frames.size == 0:
        return np.array([], dtype=np.float32)
    return np.sqrt(np.mean(frames ** 2, axis=1)).astype(np.float32)


def magnitude_spectrum(frames: np.ndarray) -> np.ndarray:
    if frames.size == 0:
        return np.empty((0, 0), dtype=np.float32)
    window = np.hanning(frames.shape[1]).astype(np.float32)
    spectrum = np.fft.rfft(frames * window, axis=1)
    return np.abs(spectrum).astype(np.float32)


def spectral_centroid(mag: np.ndarray, sr: int) -> np.ndarray:
    if mag.size == 0:
        return np.array([], dtype=np.float32)
    freqs = np.linspace(0.0, sr / 2.0, mag.shape[1], dtype=np.float32)
    num = np.sum(mag * freqs, axis=1)
    den = np.sum(mag, axis=1) + 1e-8
    return (num / den).astype(np.float32)


def spectral_rolloff(mag: np.ndarray, sr: int, rolloff_percent: float) -> np.ndarray:
    if mag.size == 0:
        return np.array([], dtype=np.float32)
    energy = np.cumsum(mag, axis=1)
    threshold = rolloff_percent * energy[:, -1][:, None]
    rolloff_bins = np.argmax(energy >= threshold, axis=1)
    freqs = np.linspace(0.0, sr / 2.0, mag.shape[1], dtype=np.float32)
    return freqs[rolloff_bins].astype(np.float32)


def extract_features(audio: np.ndarray, sr: int, config: FeatureConfig | None = None) -> Dict[str, np.ndarray]:
    if config is None:
        config = FeatureConfig()

    frames = frame_audio(audio, sr, config.frame_ms, config.hop_ms)
    mag = magnitude_spectrum(frames)

    return {
        "zcr": zero_crossing_rate(frames),
        "rms": rms_energy(frames),
        "centroid": spectral_centroid(mag, sr),
        "rolloff": spectral_rolloff(mag, sr, config.rolloff_percent),
    }
