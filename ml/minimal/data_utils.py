from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import librosa
import numpy as np


@dataclass
class DatasetBundle:
    X: np.ndarray
    y: np.ndarray
    classes: np.ndarray


def _load_npy(path: Path, allow_pickle: bool = False) -> np.ndarray:
    if not path.exists():
        raise FileNotFoundError(f"Missing file: {path}")
    return np.load(path, allow_pickle=allow_pickle)


def load_aligned_dataset(
    features_path: Path,
    labels_path: Path,
    file_names_path: Path,
    segment_order_path: Path,
    classes_path: Path | None = None,
) -> DatasetBundle:
    """
    Load features and align labels by filename.

    Why this exists:
    - In this repository, features rows can be aligned to segment_order,
      while labels are stored in a longer file_names-based array.
    - This function creates a reliable y vector that matches X row-by-row.
    """
    X = _load_npy(features_path, allow_pickle=False).astype(np.float32)
    labels = _load_npy(labels_path, allow_pickle=True).astype(str)
    file_names = _load_npy(file_names_path, allow_pickle=True).astype(str)
    segment_order = _load_npy(segment_order_path, allow_pickle=True).astype(str)

    if len(labels) != len(file_names):
        raise ValueError(
            "labels and file_names must have the same length: "
            f"{len(labels)} vs {len(file_names)}"
        )

    name_to_label: dict[str, str] = {}
    for name, label in zip(file_names.tolist(), labels.tolist()):
        name_to_label[name] = label

    missing = [name for name in segment_order.tolist() if name not in name_to_label]
    if missing:
        sample = ", ".join(missing[:5])
        raise ValueError(f"Missing labels for {len(missing)} segments. Sample: {sample}")

    y_aligned = np.array([name_to_label[name] for name in segment_order.tolist()], dtype=str)

    if len(X) != len(y_aligned):
        raise ValueError(f"Feature rows and aligned labels mismatch: {len(X)} vs {len(y_aligned)}")

    if classes_path and classes_path.exists():
        classes = _load_npy(classes_path, allow_pickle=True).astype(str)
        seen = set(classes.tolist())
        missing_classes = sorted(set(y_aligned.tolist()) - seen)
        if missing_classes:
            classes = np.array(sorted(set(classes.tolist()) | set(y_aligned.tolist())), dtype=str)
    else:
        classes = np.array(sorted(set(y_aligned.tolist())), dtype=str)

    return DatasetBundle(X=X, y=y_aligned, classes=classes)


def preprocess_mel_batch(X: np.ndarray) -> np.ndarray:
    """Convert mel power to dB and scale each sample to [0, 1]."""
    X = np.maximum(X, 1e-12).astype(np.float32)
    out = np.empty_like(X, dtype=np.float32)

    for i in range(X.shape[0]):
        mel_db = librosa.power_to_db(X[i], ref=np.max)
        mel_min = float(mel_db.min())
        mel_max = float(mel_db.max())
        out[i] = (mel_db - mel_min) / (mel_max - mel_min + 1e-6)

    return out[:, None, :, :]
