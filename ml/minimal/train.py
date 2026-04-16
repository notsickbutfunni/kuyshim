from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.model_selection import train_test_split
from torch.utils.data import DataLoader, TensorDataset

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


def evaluate(model: nn.Module, loader: DataLoader, device: torch.device) -> tuple[float, float]:
    model.eval()
    loss_fn = nn.CrossEntropyLoss()
    total_loss = 0.0
    correct = 0
    total = 0

    with torch.no_grad():
        for xb, yb in loader:
            xb = xb.to(device)
            yb = yb.to(device)
            logits = model(xb)
            loss = loss_fn(logits, yb)
            total_loss += float(loss.item()) * yb.size(0)
            preds = torch.argmax(logits, dim=1)
            correct += int((preds == yb).sum().item())
            total += int(yb.size(0))

    if total == 0:
        return 0.0, 0.0

    return total_loss / total, correct / total


def main() -> None:
    parser = argparse.ArgumentParser(description="Minimal dombra classifier training")
    parser.add_argument("--features", default="ml/data/features_transfer/X_mel_transfer_aligned.npy")
    parser.add_argument("--labels", default="ml/data/features_transfer/y_labels.npy")
    parser.add_argument("--file-names", default="ml/data/features_transfer/file_names.npy")
    parser.add_argument("--segment-order", default="ml/data/annotations/segment_order_transfer.npy")
    parser.add_argument("--classes", default="ml/data/annotations/classes_transfer.npy")
    parser.add_argument("--out-dir", default="ml/models/minimal_v1")
    parser.add_argument("--epochs", type=int, default=8)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--val-size", type=float, default=0.2)
    args = parser.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    bundle = load_aligned_dataset(
        features_path=Path(args.features),
        labels_path=Path(args.labels),
        file_names_path=Path(args.file_names),
        segment_order_path=Path(args.segment_order),
        classes_path=Path(args.classes),
    )

    X = preprocess_mel_batch(bundle.X)
    class_to_idx = {c: i for i, c in enumerate(bundle.classes.tolist())}
    y_idx = np.array([class_to_idx[label] for label in bundle.y.tolist()], dtype=np.int64)

    val_count = int(round(len(X) * args.val_size))
    use_stratify = val_count >= len(bundle.classes)
    if not use_stratify:
        print(
            "Warning: validation split is smaller than number of classes; "
            "falling back to non-stratified split."
        )

    X_train, X_val, y_train, y_val = train_test_split(
        X,
        y_idx,
        test_size=args.val_size,
        random_state=args.seed,
        stratify=y_idx if use_stratify else None,
    )

    train_ds = TensorDataset(torch.from_numpy(X_train), torch.from_numpy(y_train))
    val_ds = TensorDataset(torch.from_numpy(X_val), torch.from_numpy(y_val))
    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = SmallMelCnn(num_classes=len(bundle.classes)).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    loss_fn = nn.CrossEntropyLoss()

    best_acc = -1.0
    best_state: dict[str, torch.Tensor] | None = None
    history: list[dict[str, float]] = []

    for epoch in range(1, args.epochs + 1):
        model.train()
        run_loss = 0.0
        seen = 0
        for xb, yb in train_loader:
            xb = xb.to(device)
            yb = yb.to(device)
            optimizer.zero_grad()
            logits = model(xb)
            loss = loss_fn(logits, yb)
            loss.backward()
            optimizer.step()

            run_loss += float(loss.item()) * yb.size(0)
            seen += int(yb.size(0))

        train_loss = run_loss / max(1, seen)
        val_loss, val_acc = evaluate(model, val_loader, device)

        history.append(
            {
                "epoch": float(epoch),
                "train_loss": float(train_loss),
                "val_loss": float(val_loss),
                "val_acc": float(val_acc),
            }
        )
        print(
            f"epoch={epoch:02d} train_loss={train_loss:.4f} "
            f"val_loss={val_loss:.4f} val_acc={val_acc:.4f}"
        )

        if val_acc > best_acc:
            best_acc = val_acc
            best_state = {k: v.detach().cpu() for k, v in model.state_dict().items()}

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if best_state is None:
        raise RuntimeError("Training failed: best model state is empty")

    torch.save(best_state, out_dir / "model.pth")
    np.save(out_dir / "classes.npy", bundle.classes)

    metrics = {
        "num_samples": int(len(X)),
        "num_classes": int(len(bundle.classes)),
        "best_val_acc": float(best_acc),
        "epochs": int(args.epochs),
        "batch_size": int(args.batch_size),
        "lr": float(args.lr),
        "history": history,
    }
    with open(out_dir / "metrics.json", "w", encoding="utf-8") as f:
        json.dump(metrics, f, indent=2)

    print(f"Saved: {out_dir / 'model.pth'}")
    print(f"Saved: {out_dir / 'classes.npy'}")
    print(f"Saved: {out_dir / 'metrics.json'}")


if __name__ == "__main__":
    main()
