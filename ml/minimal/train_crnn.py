from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.model_selection import train_test_split
from torch.utils.data import DataLoader, TensorDataset

from crnn_model import DombraCRNN, audio_to_cqt_input


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
            pred = torch.argmax(logits, dim=1)
            correct += int((pred == yb).sum().item())
            total += int(yb.size(0))

    if total == 0:
        return 0.0, 0.0
    return total_loss / total, correct / total


def main() -> None:
    parser = argparse.ArgumentParser(description="Train CRNN with CQT features on processed notes")
    parser.add_argument("--audio-dir", default="ml/data/processed_notes_transfer")
    parser.add_argument("--classes", default="ml/data/annotations/classes_transfer.npy")
    parser.add_argument("--out-dir", default="ml/models/crnn_v1")
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--lr", type=float, default=1e-3)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--val-size", type=float, default=0.2)
    parser.add_argument("--sr", type=int, default=22050)
    parser.add_argument("--n-bins", type=int, default=84)
    parser.add_argument("--bins-per-octave", type=int, default=12)
    parser.add_argument("--target-frames", type=int, default=256)
    args = parser.parse_args()

    torch.manual_seed(args.seed)
    np.random.seed(args.seed)

    audio_dir = Path(args.audio_dir)
    if not audio_dir.exists():
        raise FileNotFoundError(f"Missing audio dir: {audio_dir}")

    classes = np.load(Path(args.classes), allow_pickle=True).astype(str)
    class_to_idx = {c: i for i, c in enumerate(classes.tolist())}

    pattern = re.compile(r"^(s\d+_f\d+)_")
    files = sorted(audio_dir.glob("*.wav"))
    X_list: list[np.ndarray] = []
    y_list: list[int] = []

    for fp in files:
        m = pattern.match(fp.name)
        if not m:
            continue
        label = m.group(1)
        if label not in class_to_idx:
            continue
        x = audio_to_cqt_input(
            fp,
            sr=args.sr,
            n_bins=args.n_bins,
            bins_per_octave=args.bins_per_octave,
            target_frames=args.target_frames,
        )
        X_list.append(x.numpy()[0])
        y_list.append(class_to_idx[label])

    if not X_list:
        raise RuntimeError("No valid training samples found in processed notes folder")

    X = np.stack(X_list, axis=0).astype(np.float32)
    y = np.array(y_list, dtype=np.int64)

    val_count = int(round(len(X) * args.val_size))
    use_stratify = val_count >= len(classes)
    if not use_stratify:
        print("Warning: validation split too small for stratification; using random split")

    X_train, X_val, y_train, y_val = train_test_split(
        X,
        y,
        test_size=args.val_size,
        random_state=args.seed,
        stratify=y if use_stratify else None,
    )

    train_ds = TensorDataset(torch.from_numpy(X_train), torch.from_numpy(y_train))
    val_ds = TensorDataset(torch.from_numpy(X_val), torch.from_numpy(y_val))
    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = DombraCRNN(num_classes=len(classes), n_bins=args.n_bins).to(device)
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

    if best_state is None:
        raise RuntimeError("Training failed: empty best_state")

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    torch.save(best_state, out_dir / "model.pth")
    np.save(out_dir / "classes.npy", classes)

    config = {
        "sr": int(args.sr),
        "n_bins": int(args.n_bins),
        "bins_per_octave": int(args.bins_per_octave),
        "target_frames": int(args.target_frames),
    }
    with open(out_dir / "feature_config.json", "w", encoding="utf-8") as f:
        json.dump(config, f, indent=2)

    metrics = {
        "num_samples": int(len(X)),
        "num_classes": int(len(classes)),
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
    print(f"Saved: {out_dir / 'feature_config.json'}")
    print(f"Saved: {out_dir / 'metrics.json'}")


if __name__ == "__main__":
    main()
