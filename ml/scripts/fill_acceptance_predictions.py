from __future__ import annotations

import argparse
import csv
from pathlib import Path

import librosa
import numpy as np
import torch
import torch.nn as nn
from torchvision import models


def pad_or_trim(mat: np.ndarray, target_frames: int) -> np.ndarray:
    if mat.shape[1] == target_frames:
        return mat
    if mat.shape[1] > target_frames:
        return mat[:, :target_frames]
    pad = np.zeros((mat.shape[0], target_frames - mat.shape[1]), dtype=mat.dtype)
    return np.concatenate([mat, pad], axis=1)


def prepare_mel_from_audio(audio_path: Path, sr: int = 22050, n_mels: int = 128, target_frames: int = 128) -> np.ndarray:
    y, sr = librosa.load(str(audio_path), sr=sr, mono=True)
    if y.size == 0:
        raise ValueError(f"Empty audio: {audio_path}")

    mel = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=n_mels).astype(np.float32)
    mel = pad_or_trim(mel, target_frames)

    mel = np.log1p(np.maximum(mel, 0.0))
    mean = float(np.mean(mel))
    std = float(np.std(mel) + 1e-6)
    mel = (mel - mean) / std
    return mel[None, None, :, :]


class MultiTaskFineTuneModel(nn.Module):
    def __init__(self, num_outputs: int):
        super().__init__()
        backbone = models.resnet18(weights=None)

        old_conv = backbone.conv1
        backbone.conv1 = nn.Conv2d(
            1,
            old_conv.out_channels,
            kernel_size=old_conv.kernel_size,
            stride=old_conv.stride,
            padding=old_conv.padding,
            bias=False,
        )

        feat_dim = backbone.fc.in_features
        backbone.fc = nn.Identity()
        self.backbone = backbone
        self.onset_head = nn.Sequential(
            nn.Linear(feat_dim, 256),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(256, num_outputs),
        )
        self.frame_head = nn.Sequential(
            nn.Linear(feat_dim, 256),
            nn.ReLU(),
            nn.Dropout(0.2),
            nn.Linear(256, num_outputs),
        )

    def forward(self, x: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        feats = self.backbone(x)
        return self.onset_head(feats), self.frame_head(feats)


def load_model(model_path: Path, num_classes: int, device: torch.device) -> MultiTaskFineTuneModel:
    model = MultiTaskFineTuneModel(num_outputs=num_classes).to(device)
    checkpoint = torch.load(model_path, map_location=device)
    if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
        state = checkpoint["model_state_dict"]
    elif isinstance(checkpoint, dict):
        state = checkpoint
    else:
        raise SystemExit("Unsupported checkpoint format.")

    model.load_state_dict(state, strict=False)
    model.eval()
    return model


def predict_top2(
    model: MultiTaskFineTuneModel,
    audio_path: Path,
    display_classes: np.ndarray,
    device: torch.device,
    frame_weight: float,
) -> tuple[str, float, float]:
    x_np = prepare_mel_from_audio(audio_path)
    x = torch.from_numpy(x_np).float().to(device)

    with torch.no_grad():
        onset_logits, frame_logits = model(x)
        onset_probs = torch.sigmoid(onset_logits).cpu().numpy().flatten()
        frame_probs = torch.sigmoid(frame_logits).cpu().numpy().flatten()

    probs = frame_weight * frame_probs + (1.0 - frame_weight) * onset_probs
    top_indices = np.argsort(probs)[::-1]
    top1_idx = int(top_indices[0])
    top2_idx = int(top_indices[1]) if len(top_indices) > 1 else top1_idx

    pred_label = str(display_classes[top1_idx])
    top1_prob = float(probs[top1_idx])
    top2_prob = float(probs[top2_idx])
    return pred_label, top1_prob, top2_prob


def main() -> None:
    parser = argparse.ArgumentParser(description="Auto-fill acceptance CSV predictions from a trained multitask model")
    parser.add_argument("--input-csv", required=True, help="CSV with clip_path and expected_label columns")
    parser.add_argument("--output-csv", required=True, help="Output CSV path with predicted columns filled")
    parser.add_argument("--model", default="ml/models/release_demo_v1/basic_pitch_finetune_scaffold.pth")
    parser.add_argument("--classes", default="ml/models/release_demo_v1/classes.npy")
    parser.add_argument(
        "--display-classes",
        default="ml/data/annotations/classes_transfer.npy",
        help="Optional class-name array used for pred_label output (must match class count)",
    )
    parser.add_argument("--frame-weight", type=float, default=0.7, help="Blend weight for frame head in final score")
    parser.add_argument("--device", default="cpu", choices=["cpu", "cuda"])
    args = parser.parse_args()

    in_path = Path(args.input_csv).resolve()
    out_path = Path(args.output_csv).resolve()
    model_path = Path(args.model).resolve()
    classes_path = Path(args.classes).resolve()
    display_classes_path = Path(args.display_classes).resolve() if args.display_classes else None

    if not in_path.exists():
        raise SystemExit(f"Input CSV not found: {in_path}")
    if not model_path.exists():
        raise SystemExit(f"Model not found: {model_path}")
    if not classes_path.exists():
        raise SystemExit(f"Classes file not found: {classes_path}")

    model_classes = np.load(classes_path, allow_pickle=True)
    display_classes = model_classes

    if display_classes_path and display_classes_path.exists():
        candidate = np.load(display_classes_path, allow_pickle=True)
        if len(candidate) == len(model_classes):
            display_classes = candidate
        else:
            raise SystemExit(
                f"display-classes length mismatch: {len(candidate)} != {len(model_classes)}"
            )

    device = torch.device("cuda" if (args.device == "cuda" and torch.cuda.is_available()) else "cpu")
    model = load_model(model_path, int(len(model_classes)), device)

    with open(in_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        raise SystemExit("Input CSV has no rows.")

    for row in rows:
        clip = (row.get("clip_path") or "").strip()
        if not clip:
            row["pred_label"] = ""
            row["top1_prob"] = ""
            row["top2_prob"] = ""
            row["inference_status"] = "missing_clip_path"
            continue

        clip_path = Path(clip)
        if not clip_path.is_absolute():
            clip_path = (Path.cwd() / clip_path).resolve()

        if not clip_path.exists():
            row["pred_label"] = ""
            row["top1_prob"] = ""
            row["top2_prob"] = ""
            row["inference_status"] = "clip_not_found"
            continue

        try:
            pred_label, top1_prob, top2_prob = predict_top2(
                model=model,
                audio_path=clip_path,
                display_classes=display_classes,
                device=device,
                frame_weight=args.frame_weight,
            )
            row["pred_label"] = pred_label
            row["top1_prob"] = f"{top1_prob:.6f}"
            row["top2_prob"] = f"{top2_prob:.6f}"
            row["inference_status"] = "ok"
        except Exception as exc:
            row["pred_label"] = ""
            row["top1_prob"] = ""
            row["top2_prob"] = ""
            row["inference_status"] = f"error:{type(exc).__name__}"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0].keys())
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Saved predictions CSV: {out_path}")


if __name__ == "__main__":
    main()
