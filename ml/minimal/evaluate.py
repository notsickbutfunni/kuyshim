from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import train_test_split

from data_utils import load_aligned_dataset, preprocess_mel_batch


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
        return self.head(x)


def topk_accuracy(y_true: np.ndarray, probs: np.ndarray, k: int) -> float:
    order = np.argsort(-probs, axis=1)[:, :k]
    hits = 0
    for i in range(len(y_true)):
        if int(y_true[i]) in order[i]:
            hits += 1
    return hits / max(1, len(y_true))


def save_confusion_csv(cm: np.ndarray, classes: np.ndarray, out_path: Path) -> None:
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["true\\pred"] + classes.tolist())
        for i, cls_name in enumerate(classes.tolist()):
            writer.writerow([cls_name] + cm[i].tolist())


def save_topk_errors(
    probs: np.ndarray,
    y_true: np.ndarray,
    classes: np.ndarray,
    out_path: Path,
    k: int = 5,
) -> None:
    order = np.argsort(-probs, axis=1)
    with open(out_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["sample_idx", "true", "pred", "topk"])
        for i in range(len(y_true)):
            pred = int(order[i, 0])
            if pred == int(y_true[i]):
                continue
            top_ids = order[i, :k]
            top_items = [f"{classes[j]}:{probs[i, j]:.4f}" for j in top_ids]
            writer.writerow([i, classes[int(y_true[i])], classes[pred], " | ".join(top_items)])


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate minimal dombra classifier")
    parser.add_argument("--features", default="ml/data/features_transfer/X_mel_transfer_aligned.npy")
    parser.add_argument("--labels", default="ml/data/features_transfer/y_labels.npy")
    parser.add_argument("--file-names", default="ml/data/features_transfer/file_names.npy")
    parser.add_argument("--segment-order", default="ml/data/annotations/segment_order_transfer.npy")
    parser.add_argument("--classes", default="ml/models/minimal_smoke/classes.npy")
    parser.add_argument("--model", default="ml/models/minimal_smoke/model.pth")
    parser.add_argument("--out-dir", default="ml/models/minimal_smoke/eval")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--val-size", type=float, default=0.2)
    parser.add_argument("--split", choices=["val", "full"], default="val")
    args = parser.parse_args()

    model_path = Path(args.model)
    classes_path = Path(args.classes)
    if not model_path.exists():
        raise FileNotFoundError(f"Missing model file: {model_path}")
    if not classes_path.exists():
        raise FileNotFoundError(f"Missing classes file: {classes_path}")

    bundle = load_aligned_dataset(
        features_path=Path(args.features),
        labels_path=Path(args.labels),
        file_names_path=Path(args.file_names),
        segment_order_path=Path(args.segment_order),
        classes_path=Path(args.classes),
    )

    X = preprocess_mel_batch(bundle.X)
    classes = np.load(classes_path, allow_pickle=True).astype(str)
    class_to_idx = {c: i for i, c in enumerate(classes.tolist())}
    y_idx = np.array([class_to_idx[label] for label in bundle.y.tolist()], dtype=np.int64)

    if args.split == "val":
        val_count = int(round(len(X) * args.val_size))
        use_stratify = val_count >= len(classes)
        _, X_eval, _, y_eval = train_test_split(
            X,
            y_idx,
            test_size=args.val_size,
            random_state=args.seed,
            stratify=y_idx if use_stratify else None,
        )
    else:
        X_eval = X
        y_eval = y_idx

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = SmallMelCnn(num_classes=len(classes)).to(device)
    model.load_state_dict(torch.load(model_path, map_location=device))
    model.eval()

    with torch.no_grad():
        logits = model(torch.from_numpy(X_eval).to(device))
        probs = torch.softmax(logits, dim=1).cpu().numpy()

    pred = np.argmax(probs, axis=1)
    top1 = float(np.mean(pred == y_eval)) if len(y_eval) > 0 else 0.0
    top3 = float(topk_accuracy(y_eval, probs, k=3))
    top5 = float(topk_accuracy(y_eval, probs, k=5))

    cm = confusion_matrix(y_eval, pred, labels=np.arange(len(classes)))

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    save_confusion_csv(cm, classes, out_dir / "confusion_matrix.csv")
    save_topk_errors(probs, y_eval, classes, out_dir / "topk_errors.csv", k=5)

    metrics = {
        "split": args.split,
        "num_samples": int(len(y_eval)),
        "top1_acc": top1,
        "top3_acc": top3,
        "top5_acc": top5,
    }
    with open(out_dir / "metrics.json", "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)

    print(json.dumps(metrics, indent=2))
    print(f"Saved: {out_dir / 'confusion_matrix.csv'}")
    print(f"Saved: {out_dir / 'topk_errors.csv'}")


if __name__ == "__main__":
    main()
