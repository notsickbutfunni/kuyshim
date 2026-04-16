from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch

from crnn_model import DombraCRNN, audio_to_cqt_input


def main() -> None:
    parser = argparse.ArgumentParser(description="Predict dombra class with CRNN+CQT")
    parser.add_argument("--audio", required=True)
    parser.add_argument("--model", default="ml/models/crnn_v1/model.pth")
    parser.add_argument("--classes", default="ml/models/crnn_v1/classes.npy")
    parser.add_argument("--feature-config", default="ml/models/crnn_v1/feature_config.json")
    parser.add_argument("--top-k", type=int, default=5)
    args = parser.parse_args()

    audio_path = Path(args.audio)
    model_path = Path(args.model)
    classes_path = Path(args.classes)
    cfg_path = Path(args.feature_config)

    if not audio_path.exists():
        raise FileNotFoundError(f"Missing audio: {audio_path}")
    if not model_path.exists():
        raise FileNotFoundError(f"Missing model: {model_path}")
    if not classes_path.exists():
        raise FileNotFoundError(f"Missing classes: {classes_path}")
    if not cfg_path.exists():
        raise FileNotFoundError(f"Missing feature config: {cfg_path}")

    classes = np.load(classes_path, allow_pickle=True).astype(str)
    with open(cfg_path, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    model = DombraCRNN(num_classes=len(classes), n_bins=int(cfg["n_bins"]))
    state = torch.load(model_path, map_location="cpu")
    model.load_state_dict(state)
    model.eval()

    x = audio_to_cqt_input(
        audio_path,
        sr=int(cfg["sr"]),
        n_bins=int(cfg["n_bins"]),
        bins_per_octave=int(cfg["bins_per_octave"]),
        target_frames=int(cfg["target_frames"]),
    )

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
