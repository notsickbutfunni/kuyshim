from __future__ import annotations

import argparse
from typing import List

import numpy as np
import torch

from .chroma_extractor import ChromaConfig, compute_chroma_from_file
from .model import build_model


def predict(audio_path: str, model_path: str, chord_list: List[str] | None = None) -> None:
    if chord_list is None:
        chord_list 

    chroma, _ = compute_chroma_from_file(audio_path, ChromaConfig())
    x = torch.tensor(chroma, dtype=torch.float32).unsqueeze(0).unsqueeze(0)

    model = build_model(num_classes=len(chord_list))
    model.load_state_dict(torch.load(model_path, map_location="cpu"))
    model.eval()

    with torch.no_grad():
        logits = model(x)
        probs = torch.softmax(logits, dim=1).numpy().flatten()

    top_idx = int(np.argmax(probs))
    print(f"Prediction: {chord_list[top_idx]} ({probs[top_idx]:.4f})")


def main() -> None:
    parser = argparse.ArgumentParser(description="Predict chord from audio file.")
    parser.add_argument("--audio", required=True, help="Path to .wav file")
    parser.add_argument("--model", required=True, help="Path to model .pth")
    args = parser.parse_args()

    predict(args.audio, args.model)


if __name__ == "__main__":
    main()
