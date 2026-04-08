"""
inference.py
────────────
ML inference engine for dombra chord/fret recognition.

Loads a trained ResNet18 transfer-learning model and provides
prediction + performance-evaluation functions.
"""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import librosa
import numpy as np
import torch
import torch.nn as nn

logger = logging.getLogger(__name__)

# ── Default paths ────────────────────────────────────────────────
_DEFAULT_MODEL_DIR = Path(__file__).resolve().parent / "models" / "trained_models" / "cnn_transfer_v1"


# ── ResNet18 builder (must match training script) ────────────────
def _build_resnet18(num_classes: int, pretrained: bool = False) -> nn.Module:
    """Build a ResNet18 with 1-channel input (grayscale spectrogram)."""
    from torchvision import models as tv_models

    weights = tv_models.ResNet18_Weights.DEFAULT if pretrained else None
    model = tv_models.resnet18(weights=weights)

    # Replace first conv: 3-channel → 1-channel
    old_conv = model.conv1
    model.conv1 = nn.Conv2d(
        1, old_conv.out_channels,
        kernel_size=old_conv.kernel_size,
        stride=old_conv.stride,
        padding=old_conv.padding,
        bias=False,
    )

    # Replace classifier head
    model.fc = nn.Linear(model.fc.in_features, num_classes)
    return model


# ── Singleton model holder ───────────────────────────────────────
@dataclass
class _ModelState:
    model: nn.Module | None = None
    class_names: List[str] | None = None
    device: torch.device | None = None
    loaded: bool = False


_state = _ModelState()


def load_model(model_dir: Path | str | None = None) -> None:
    """
    Load the trained CNN checkpoint and class names.
    Called once at API startup.
    """
    model_dir = Path(model_dir) if model_dir else _DEFAULT_MODEL_DIR

    ckpt_path = model_dir / "cnn_transfer_resnet18.pth"
    classes_path = model_dir / "classes.npy"

    if not ckpt_path.exists():
        raise FileNotFoundError(f"Model checkpoint not found: {ckpt_path}")
    if not classes_path.exists():
        raise FileNotFoundError(f"Classes file not found: {classes_path}")

    # Load class names
    class_names = np.load(classes_path, allow_pickle=True).tolist()
    num_classes = len(class_names)
    logger.info("Loaded %d classes: %s", num_classes, class_names)

    # Load checkpoint
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    checkpoint = torch.load(ckpt_path, map_location=device)

    # The training script saves either a dict with 'model_state_dict' or raw state_dict
    if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
        state_dict = checkpoint["model_state_dict"]
    else:
        state_dict = checkpoint

    model = _build_resnet18(num_classes=num_classes, pretrained=False)
    model.load_state_dict(state_dict)
    model.to(device)
    model.eval()

    _state.model = model
    _state.class_names = class_names
    _state.device = device
    _state.loaded = True

    logger.info("Model loaded on %s", device)


def is_loaded() -> bool:
    return _state.loaded


# ── Audio → mel-spectrogram ──────────────────────────────────────
def _audio_bytes_to_mel(audio_bytes: bytes, sr: int = 22050, n_mels: int = 128, target_frames: int = 128) -> np.ndarray:
    """
    Convert raw audio bytes → mel-spectrogram (same pipeline as extract_features.py).
    Returns shape (1, n_mels, target_frames) ready for the model.
    """
    # Load audio from bytes
    audio, file_sr = librosa.load(io.BytesIO(audio_bytes), sr=sr, mono=True)

    if len(audio) == 0:
        raise ValueError("Audio file is empty or could not be decoded")

    # Compute mel spectrogram
    mel = librosa.feature.melspectrogram(y=audio, sr=sr, n_mels=n_mels)

    # Pad or trim to fixed width
    if mel.shape[1] > target_frames:
        mel = mel[:, :target_frames]
    elif mel.shape[1] < target_frames:
        pad_width = target_frames - mel.shape[1]
        mel = np.concatenate([mel, np.zeros((n_mels, pad_width), dtype=mel.dtype)], axis=1)

    # Apply log and normalize (same as training: prepare_inputs)
    mel = mel.astype(np.float32)
    mel = np.log1p(np.maximum(mel, 0.0))
    mean = mel.mean()
    std = mel.std() + 1e-6
    mel = (mel - mean) / std

    # Add channel dimension → (1, n_mels, target_frames)
    return mel[None, :, :]


# ── Prediction ───────────────────────────────────────────────────
@dataclass
class PredictionResult:
    predicted_class: str
    confidence: float
    all_probabilities: Dict[str, float]


def predict_chord(audio_bytes: bytes) -> PredictionResult:
    """
    Predict which chord/fret is being played in the given audio.

    Parameters
    ----------
    audio_bytes : bytes
        Raw audio file content (WAV, MP3, OGG, etc.)

    Returns
    -------
    PredictionResult with predicted class, confidence, and all probabilities.
    """
    if not _state.loaded:
        raise RuntimeError("Model not loaded. Call load_model() first.")

    mel = _audio_bytes_to_mel(audio_bytes)
    x = torch.tensor(mel, dtype=torch.float32).unsqueeze(0).to(_state.device)  # (1, 1, n_mels, frames)

    with torch.no_grad():
        logits = _state.model(x)
        probs = torch.softmax(logits, dim=1).cpu().numpy().flatten()

    top_idx = int(np.argmax(probs))
    predicted_class = _state.class_names[top_idx]
    confidence = float(probs[top_idx])

    all_probs = {
        _state.class_names[i]: float(probs[i])
        for i in range(len(_state.class_names))
    }

    return PredictionResult(
        predicted_class=predicted_class,
        confidence=confidence,
        all_probabilities=all_probs,
    )


# ── Performance evaluation ───────────────────────────────────────
@dataclass
class EvaluationResult:
    accuracy: float           # 0–100: how close the chord matches reference
    timing_offset: float      # 0–100: how far off the timing is (lower is better)
    note_consistency: float   # 0–100: consistency of note production
    predicted_chord: str
    reference_chord: str
    final_score: float


def _compute_chroma_similarity(user_audio: bytes, ref_audio: bytes, sr: int = 22050) -> float:
    """
    Compute cosine similarity between chroma features of two audio clips.
    Returns a value between 0 and 100.
    """
    user_y, _ = librosa.load(io.BytesIO(user_audio), sr=sr, mono=True)
    ref_y, _ = librosa.load(io.BytesIO(ref_audio), sr=sr, mono=True)

    if len(user_y) == 0 or len(ref_y) == 0:
        return 0.0

    user_chroma = librosa.feature.chroma_cqt(y=user_y, sr=sr)
    ref_chroma = librosa.feature.chroma_cqt(y=ref_y, sr=sr)

    # Average chroma across time
    user_avg = user_chroma.mean(axis=1)
    ref_avg = ref_chroma.mean(axis=1)

    # Cosine similarity
    dot = np.dot(user_avg, ref_avg)
    norm = (np.linalg.norm(user_avg) * np.linalg.norm(ref_avg)) + 1e-8
    similarity = float(dot / norm)

    return max(0.0, min(100.0, similarity * 100.0))


def _compute_timing_offset(user_audio: bytes, ref_audio: bytes, sr: int = 22050) -> float:
    """
    Estimate timing offset by comparing onset patterns.
    Returns a value between 0 and 100 (lower means more in sync).
    """
    user_y, _ = librosa.load(io.BytesIO(user_audio), sr=sr, mono=True)
    ref_y, _ = librosa.load(io.BytesIO(ref_audio), sr=sr, mono=True)

    if len(user_y) == 0 or len(ref_y) == 0:
        return 100.0

    user_onsets = librosa.onset.onset_detect(y=user_y, sr=sr, units="time")
    ref_onsets = librosa.onset.onset_detect(y=ref_y, sr=sr, units="time")

    if len(user_onsets) == 0 or len(ref_onsets) == 0:
        return 50.0  # Can't compare, return neutral

    # Compare onset counts
    count_diff = abs(len(user_onsets) - len(ref_onsets))
    max_onsets = max(len(user_onsets), len(ref_onsets))
    count_ratio = count_diff / max_onsets

    # Compare onset timing (match closest pairs)
    min_len = min(len(user_onsets), len(ref_onsets))
    time_diffs = []
    for i in range(min_len):
        time_diffs.append(abs(user_onsets[i] - ref_onsets[i]))

    avg_diff = np.mean(time_diffs) if time_diffs else 1.0

    # Convert to 0–100 scale (lower = better timing, higher = worse)
    timing_offset = min(100.0, (avg_diff * 50.0) + (count_ratio * 50.0))
    return float(timing_offset)


def _compute_note_consistency(user_audio: bytes, sr: int = 22050) -> float:
    """
    Measure how consistently the user produces notes.
    Uses spectral flatness and RMS energy variance.
    Returns 0–100 (higher = more consistent).
    """
    user_y, _ = librosa.load(io.BytesIO(user_audio), sr=sr, mono=True)

    if len(user_y) == 0:
        return 0.0

    # RMS energy consistency
    rms = librosa.feature.rms(y=user_y).flatten()
    if len(rms) > 1:
        rms_cv = float(np.std(rms) / (np.mean(rms) + 1e-8))  # coefficient of variation
    else:
        rms_cv = 0.0

    # Spectral flatness (0 = tonal, 1 = noise-like)
    flatness = librosa.feature.spectral_flatness(y=user_y).mean()

    # Combine: lower CV + lower flatness = higher consistency
    consistency = max(0.0, 100.0 - (rms_cv * 30.0) - (float(flatness) * 70.0))
    return min(100.0, consistency)


def evaluate_performance(
    user_audio: bytes,
    reference_audio: bytes,
) -> EvaluationResult:
    """
    Compare user's audio performance against a reference.

    Parameters
    ----------
    user_audio : bytes
        User's recorded audio.
    reference_audio : bytes
        Reference audio from the lesson.

    Returns
    -------
    EvaluationResult with accuracy, timing, consistency, and final score.
    """
    # Get chord predictions
    user_pred = predict_chord(user_audio)
    ref_pred = predict_chord(reference_audio)

    # Compute metrics
    accuracy = _compute_chroma_similarity(user_audio, reference_audio)
    timing_offset = _compute_timing_offset(user_audio, reference_audio)
    note_consistency = _compute_note_consistency(user_audio)

    # Final score formula (same as backend's existing formula)
    final_score = (
        (accuracy * 0.5)
        + ((100 - timing_offset) * 0.3)
        + (note_consistency * 0.2)
    )

    return EvaluationResult(
        accuracy=round(accuracy, 2),
        timing_offset=round(timing_offset, 2),
        note_consistency=round(note_consistency, 2),
        predicted_chord=user_pred.predicted_class,
        reference_chord=ref_pred.predicted_class,
        final_score=round(final_score, 2),
    )
