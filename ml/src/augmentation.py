from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import librosa
import numpy as np


@dataclass(frozen=True)
class AugmentationConfig:
    stretch_min: float = 0.95
    stretch_max: float = 1.05
    max_pitch_cents: float = 20.0
    noise_snr_min_db: float = 18.0
    noise_snr_max_db: float = 28.0
    p_time_stretch: float = 0.8
    p_pitch_shift: float = 0.8
    p_background_noise: float = 0.6
    noise_dir: str | None = None
    seed: int = 42


def _match_length(audio: np.ndarray, target_len: int) -> np.ndarray:
    if target_len <= 0:
        return np.zeros(0, dtype=np.float32)
    if len(audio) == target_len:
        return audio.astype(np.float32)
    if len(audio) > target_len:
        return audio[:target_len].astype(np.float32)
    pad = np.zeros(target_len - len(audio), dtype=np.float32)
    return np.concatenate([audio.astype(np.float32), pad])


def mix_background_noise(audio: np.ndarray, noise: np.ndarray, snr_db: float) -> np.ndarray:
    if len(audio) == 0:
        return audio.astype(np.float32)

    audio = audio.astype(np.float32)
    noise = _match_length(noise.astype(np.float32), len(audio))

    signal_rms = float(np.sqrt(np.mean(audio**2)) + 1e-8)
    noise_rms = float(np.sqrt(np.mean(noise**2)) + 1e-8)
    if noise_rms <= 1e-8:
        return audio

    target_noise_rms = signal_rms / (10.0 ** (snr_db / 20.0))
    scaled_noise = noise * (target_noise_rms / noise_rms)
    mixed = audio + scaled_noise

    peak = float(np.max(np.abs(mixed)) + 1e-8)
    if peak > 1.0:
        mixed = mixed / peak
    return mixed.astype(np.float32)


class AudioAugmentor:
    def __init__(self, config: AugmentationConfig):
        self.config = config
        self.rng = np.random.default_rng(config.seed)
        self._noise_files: list[Path] = []

        if config.noise_dir:
            noise_dir = Path(config.noise_dir)
            if noise_dir.exists() and noise_dir.is_dir():
                self._noise_files = sorted(noise_dir.glob("*.wav"))

    def _load_noise(self, sr: int, target_len: int) -> np.ndarray:
        if self._noise_files:
            noise_file = self._noise_files[int(self.rng.integers(0, len(self._noise_files)))]
            noise_audio, _ = librosa.load(str(noise_file), sr=sr, mono=True)
            return _match_length(noise_audio, target_len)
        # Fallback: synthetic low-amplitude noise when no noise bank exists.
        return self.rng.normal(0.0, 0.01, size=target_len).astype(np.float32)

    def augment(self, audio: np.ndarray, sr: int) -> tuple[np.ndarray, dict[str, Any]]:
        if len(audio) == 0:
            return audio.astype(np.float32), {}

        out = audio.astype(np.float32).copy()
        original_len = len(out)
        meta: dict[str, Any] = {}

        if self.rng.random() < self.config.p_time_stretch:
            rate = float(self.rng.uniform(self.config.stretch_min, self.config.stretch_max))
            out = librosa.effects.time_stretch(out, rate=rate)
            out = _match_length(out, original_len)
            meta["time_stretch_rate"] = rate

        if self.rng.random() < self.config.p_pitch_shift:
            cents = float(self.rng.uniform(-self.config.max_pitch_cents, self.config.max_pitch_cents))
            steps = cents / 100.0
            out = librosa.effects.pitch_shift(out, sr=sr, n_steps=steps)
            out = _match_length(out, original_len)
            meta["pitch_shift_cents"] = cents

        if self.rng.random() < self.config.p_background_noise:
            snr_db = float(self.rng.uniform(self.config.noise_snr_min_db, self.config.noise_snr_max_db))
            noise = self._load_noise(sr, original_len)
            out = mix_background_noise(out, noise, snr_db=snr_db)
            meta["noise_snr_db"] = snr_db

        out = _match_length(out, original_len)
        peak = float(np.max(np.abs(out)) + 1e-8)
        if peak > 1.0:
            out = out / peak

        return out.astype(np.float32), meta
