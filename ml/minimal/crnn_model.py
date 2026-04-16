from __future__ import annotations

from pathlib import Path

import librosa
import numpy as np
import torch
import torch.nn as nn


class DombraCRNN(nn.Module):
    def __init__(
        self,
        num_classes: int,
        n_bins: int = 84,
        hidden_size: int = 128,
        rnn_layers: int = 2,
    ):
        super().__init__()
        self.n_bins = n_bins
        self.conv_stack = nn.Sequential(
            nn.Conv2d(1, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.MaxPool2d(kernel_size=(2, 2)),
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.MaxPool2d(kernel_size=(2, 1)),
        )

        conv_freq_bins = n_bins // 4
        self.rnn = nn.GRU(
            input_size=64 * conv_freq_bins,
            hidden_size=hidden_size,
            num_layers=rnn_layers,
            batch_first=True,
            bidirectional=True,
            dropout=0.2 if rnn_layers > 1 else 0.0,
        )
        self.fc = nn.Linear(hidden_size * 2, num_classes)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.conv_stack(x)
        b, c, f, t = x.size()
        x = x.permute(0, 3, 1, 2).contiguous().view(b, t, c * f)
        x, _ = self.rnn(x)
        return self.fc(x[:, -1, :])


def audio_to_cqt_input(
    audio_path: Path,
    sr: int = 22050,
    n_bins: int = 84,
    bins_per_octave: int = 12,
    target_frames: int = 256,
) -> torch.Tensor:
    y, _ = librosa.load(str(audio_path), sr=sr, mono=True)
    if len(y) == 0:
        raise ValueError("Audio is empty or unreadable")

    # Very short notes can trigger unstable tiny-window CQT behavior; pad to a safe minimum.
    if len(y) < 2048:
        y = librosa.util.fix_length(y, size=2048)

    cqt = np.abs(librosa.cqt(y, sr=sr, n_bins=n_bins, bins_per_octave=bins_per_octave)).astype(np.float32)
    if cqt.shape[1] > target_frames:
        cqt = cqt[:, :target_frames]
    elif cqt.shape[1] < target_frames:
        pad = target_frames - cqt.shape[1]
        cqt = np.concatenate([cqt, np.zeros((n_bins, pad), dtype=np.float32)], axis=1)

    cqt_db = librosa.amplitude_to_db(np.maximum(cqt, 1e-12), ref=np.max).astype(np.float32)
    cqt_norm = (cqt_db - cqt_db.mean()) / (cqt_db.std() + 1e-6)
    return torch.from_numpy(cqt_norm[None, None, :, :]).float()
