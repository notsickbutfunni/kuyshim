from __future__ import annotations

import argparse
from pathlib import Path

import librosa
import numpy as np
import torch
import torch.nn as nn


class SmallMelCnn(nn.Module):
    def __init__(self, num_classes: int):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(1, 16, kernel_size=3, padding=1),
            nn.BatchNorm2d(16),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(16, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.AdaptiveAvgPool2d((4, 4)),
        )
        self.head = nn.Sequential(
            nn.Flatten(),
            nn.Linear(64 * 4 * 4, 128),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(128, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.features(x)
        x = x.flatten(1)
        return self.head(x)


def audio_to_input(
    audio_path: Path,
    sr: int = 22050,
    n_mels: int = 128,
    n_fft: int = 2048,
    target_frames: int = 128,
) -> torch.Tensor:
    y, _ = librosa.load(str(audio_path), sr=sr, mono=True)
    if len(y) == 0:
        raise ValueError("Audio is empty or unreadable")

    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=n_mels, n_fft=n_fft).astype(np.float32)
    if mel.shape[1] > target_frames:
        mel = mel[:, :target_frames]
    elif mel.shape[1] < target_frames:
        pad = target_frames - mel.shape[1]
        mel = np.concatenate([mel, np.zeros((n_mels, pad), dtype=np.float32)], axis=1)

    mel_db = librosa.power_to_db(np.maximum(mel, 1e-12), ref=np.max).astype(np.float32)
    mel = (mel_db - mel_db.min()) / (mel_db.max() - mel_db.min() + 1e-6)
    x = torch.from_numpy(mel[None, None, :, :])
    return x


def main() -> None:
    parser = argparse.ArgumentParser(description="Predict dombra class from one audio file")
    parser.add_argument("--audio", required=True)
    parser.add_argument("--model", default="ml/models/minimal_v1/model.pth")
    parser.add_argument("--classes", default="ml/models/minimal_v1/classes.npy")
    parser.add_argument("--top-k", type=int, default=5)
    args = parser.parse_args()

    model_path = Path(args.model)
    classes_path = Path(args.classes)
    audio_path = Path(args.audio)

    if not model_path.exists():
        raise FileNotFoundError(f"Missing model: {model_path}")
    if not classes_path.exists():
        raise FileNotFoundError(f"Missing classes: {classes_path}")
    if not audio_path.exists():
        raise FileNotFoundError(f"Missing audio: {audio_path}")

    classes = np.load(classes_path, allow_pickle=True).astype(str)
    model = SmallMelCnn(num_classes=len(classes))
    state = torch.load(model_path, map_location="cpu")
    model.load_state_dict(state)
    model.eval()

    x = audio_to_input(audio_path)
    with torch.no_grad():
        logits = model(x)
        probs = torch.softmax(logits, dim=1).numpy().flatten()

    top_k = max(1, min(args.top_k, len(classes)))
    order = np.argsort(-probs)[:top_k]

    print("Top predictions:")
    for rank, idx in enumerate(order, start=1):
        print(f"{rank}. {classes[idx]}  prob={probs[idx]:.4f}")


if __name__ == "__main__":
    main()
