from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
import torch
import torch.nn as nn
from importlib import import_module
from math import ceil
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from torch.utils.data import DataLoader, Dataset


class SpectrogramDataset(Dataset):
    def __init__(self, X: np.ndarray, y: np.ndarray, augment: "SpecAugment | None" = None):
        self.X = torch.from_numpy(X).float()
        self.y = torch.from_numpy(y).long()
        self.augment = augment

    def __len__(self) -> int:
        return len(self.X)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, torch.Tensor]:
        x = self.X[idx]
        y = self.y[idx]

        if self.augment is not None:
            x = self.augment(x)

        return x, y


class SpecAugment:
    def __init__(
        self,
        noise_std: float = 0.02,
        gain_min: float = 0.8,
        gain_max: float = 1.2,
        max_time_mask_ratio: float = 0.12,
        max_freq_mask_ratio: float = 0.12,
    ):
        self.noise_std = noise_std
        self.gain_min = gain_min
        self.gain_max = gain_max
        self.max_time_mask_ratio = max_time_mask_ratio
        self.max_freq_mask_ratio = max_freq_mask_ratio

    def __call__(self, x: torch.Tensor) -> torch.Tensor:
        x = x.clone()

        gain = torch.empty(1).uniform_(self.gain_min, self.gain_max).item()
        x = x * gain

        if self.noise_std > 0:
            x = x + torch.randn_like(x) * self.noise_std

        _, h, w = x.shape
        max_t = max(1, int(w * self.max_time_mask_ratio))
        max_f = max(1, int(h * self.max_freq_mask_ratio))

        if max_t > 0 and w > 2:
            t = int(torch.randint(1, max_t + 1, (1,)).item())
            t0 = int(torch.randint(0, max(1, w - t + 1), (1,)).item())
            x[:, :, t0 : t0 + t] = 0

        if max_f > 0 and h > 2:
            f = int(torch.randint(1, max_f + 1, (1,)).item())
            f0 = int(torch.randint(0, max(1, h - f + 1), (1,)).item())
            x[:, f0 : f0 + f, :] = 0

        return x


def save_confusion_matrix(cm: np.ndarray, class_names: list[str], out_path: Path, title: str) -> None:
    plt.figure(figsize=(10, 8), dpi=300)
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=class_names, yticklabels=class_names)
    plt.title(title)
    plt.xlabel("Predicted")
    plt.ylabel("True")
    plt.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    plt.close()


def save_training_curves(history: dict[str, list[float]], out_path: Path) -> None:
    epochs = range(1, len(history["train_loss"]) + 1)

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4), dpi=200)
    ax1.plot(epochs, history["train_loss"], label="Train loss")
    ax1.plot(epochs, history["val_loss"], label="Val loss")
    ax1.set_title("Loss")
    ax1.set_xlabel("Epoch")
    ax1.set_ylabel("Cross-entropy")
    ax1.legend()

    ax2.plot(epochs, history["train_acc"], label="Train acc")
    ax2.plot(epochs, history["val_acc"], label="Val acc")
    ax2.set_title("Accuracy")
    ax2.set_xlabel("Epoch")
    ax2.set_ylabel("Accuracy")
    ax2.legend()

    fig.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out_path, bbox_inches="tight")
    plt.close(fig)


def build_transfer_model(num_classes: int, use_pretrained: bool) -> nn.Module:
    try:
        torchvision_models = import_module("torchvision.models")
    except ImportError as exc:
        raise SystemExit(
            "torchvision is required for transfer learning. Install with: pip install torchvision"
        ) from exc

    resnet18 = getattr(torchvision_models, "resnet18")
    resnet18_weights = getattr(torchvision_models, "ResNet18_Weights")

    weights = resnet18_weights.DEFAULT if use_pretrained else None
    model = resnet18(weights=weights)

    old_conv = model.conv1
    new_conv = nn.Conv2d(
        in_channels=1,
        out_channels=old_conv.out_channels,
        kernel_size=old_conv.kernel_size,
        stride=old_conv.stride,
        padding=old_conv.padding,
        bias=False,
    )

    if use_pretrained:
        with torch.no_grad():
            new_conv.weight.copy_(old_conv.weight.mean(dim=1, keepdim=True))

    model.conv1 = new_conv
    model.fc = nn.Linear(model.fc.in_features, num_classes)

    return model


def freeze_backbone(model: nn.Module) -> None:
    for name, param in model.named_parameters():
        param.requires_grad = name.startswith("conv1") or name.startswith("fc")


def unfreeze_all(model: nn.Module) -> None:
    for param in model.parameters():
        param.requires_grad = True


def prepare_inputs(X: np.ndarray) -> np.ndarray:
    X = X.astype(np.float32)
    X = np.log1p(np.maximum(X, 0.0))

    mean = X.mean(axis=(1, 2), keepdims=True)
    std = X.std(axis=(1, 2), keepdims=True) + 1e-6
    X = (X - mean) / std

    X = X[:, None, :, :]
    return X


def run_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    optimizer: torch.optim.Optimizer | None,
    device: torch.device,
) -> tuple[float, float]:
    is_train = optimizer is not None
    model.train(is_train)

    total_loss = 0.0
    correct = 0
    total = 0

    for xb, yb in loader:
        xb = xb.to(device)
        yb = yb.to(device)

        if is_train:
            optimizer.zero_grad()

        logits = model(xb)
        loss = criterion(logits, yb)

        if is_train:
            loss.backward()
            optimizer.step()

        total_loss += loss.item()
        preds = torch.argmax(logits, dim=1)
        correct += int((preds == yb).sum().item())
        total += int(yb.numel())

    avg_loss = total_loss / max(1, len(loader))
    acc = correct / max(1, total)
    return avg_loss, acc


def split_dataset(
    X: np.ndarray,
    y: np.ndarray,
    test_size: float,
    seed: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    n_samples = len(y)
    n_classes = len(np.unique(y))

    if n_samples < 2:
        raise SystemExit("Need at least 2 samples to split dataset.")

    if isinstance(test_size, float):
        requested = int(ceil(n_samples * test_size))
    else:
        requested = int(test_size)

    requested = max(1, requested)
    requested = min(requested, n_samples - 1)

    class_counts = np.bincount(y, minlength=n_classes)
    can_stratify = np.all(class_counts >= 2)

    adjusted = requested
    if can_stratify and adjusted < n_classes:
        adjusted = n_classes
        adjusted = min(adjusted, n_samples - 1)

    if adjusted >= n_samples:
        adjusted = n_samples - 1

    split_value: float | int
    if isinstance(test_size, float):
        split_value = adjusted / n_samples
    else:
        split_value = adjusted

    stratify_y = y if can_stratify and adjusted >= n_classes else None
    return train_test_split(
        X,
        y,
        test_size=split_value,
        random_state=seed,
        stratify=stratify_y,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Transfer-learning CNN on Mel-spectrogram features")
    parser.add_argument("--features", default="data/features/X_mel.npy")
    parser.add_argument("--labels", default="data/features/y_labels.npy")
    parser.add_argument("--epochs", type=int, default=25)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--fine-tune-lr", type=float, default=1e-4)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--val-size", type=float, default=0.2)
    parser.add_argument("--freeze-epochs", type=int, default=5)
    parser.add_argument("--patience", type=int, default=6)
    parser.add_argument("--num-workers", type=int, default=0)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--disable-pretrained", action="store_true")
    parser.add_argument("--disable-augment", action="store_true")
    parser.add_argument("--out-dir", default="models/cnn_optional")
    args = parser.parse_args()

    np.random.seed(args.seed)
    torch.manual_seed(args.seed)

    features_path = Path(args.features)
    labels_path = Path(args.labels)
    if not features_path.exists() or not labels_path.exists():
        raise SystemExit(
            "Feature files not found. Run scripts/extract_features.py first, "
            "or pass --features and --labels paths explicitly."
        )

    X = np.load(features_path)
    y_text = np.load(labels_path)

    if len(X) == 0:
        raise SystemExit("No features found. Run extract_features.py first.")

    encoder = LabelEncoder()
    y = encoder.fit_transform(y_text)

    X = prepare_inputs(X)

    X_train_full, X_test, y_train_full, y_test = split_dataset(
        X,
        y,
        test_size=args.test_size,
        seed=args.seed,
    )

    X_train, X_val, y_train, y_val = split_dataset(
        X_train_full,
        y_train_full,
        test_size=args.val_size,
        seed=args.seed,
    )

    augment = None if args.disable_augment else SpecAugment()

    train_ds = SpectrogramDataset(X_train, y_train, augment=augment)
    val_ds = SpectrogramDataset(X_val, y_val, augment=None)
    test_ds = SpectrogramDataset(X_test, y_test, augment=None)

    train_loader = DataLoader(
        train_ds,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
        pin_memory=True,
    )
    val_loader = DataLoader(
        val_ds,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.num_workers,
        pin_memory=True,
    )
    test_loader = DataLoader(
        test_ds,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.num_workers,
        pin_memory=True,
    )

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    use_pretrained = not args.disable_pretrained
    model = build_transfer_model(num_classes=len(encoder.classes_), use_pretrained=use_pretrained).to(device)

    freeze_backbone(model)

    class_counts = np.bincount(y_train, minlength=len(encoder.classes_)).astype(np.float32)
    class_weights = class_counts.sum() / np.maximum(class_counts, 1.0)
    class_weights = class_weights / class_weights.mean()
    criterion = nn.CrossEntropyLoss(weight=torch.tensor(class_weights, device=device))

    optimizer = torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=args.lr,
        weight_decay=args.weight_decay,
    )

    history: dict[str, list[float]] = {"train_loss": [], "val_loss": [], "train_acc": [], "val_acc": []}

    best_state = None
    best_val_loss = float("inf")
    best_epoch = 0
    wait = 0

    for epoch in range(1, args.epochs + 1):
        if epoch == args.freeze_epochs + 1:
            unfreeze_all(model)
            optimizer = torch.optim.AdamW(model.parameters(), lr=args.fine_tune_lr, weight_decay=args.weight_decay)

        train_loss, train_acc = run_epoch(model, train_loader, criterion, optimizer, device)
        val_loss, val_acc = run_epoch(model, val_loader, criterion, None, device)

        history["train_loss"].append(train_loss)
        history["val_loss"].append(val_loss)
        history["train_acc"].append(train_acc)
        history["val_acc"].append(val_acc)

        print(
            f"Epoch {epoch:02d}/{args.epochs} | "
            f"train_loss={train_loss:.4f} train_acc={train_acc:.3f} | "
            f"val_loss={val_loss:.4f} val_acc={val_acc:.3f}"
        )

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_epoch = epoch
            best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
            wait = 0
        else:
            wait += 1
            if wait >= args.patience:
                print(f"Early stopping at epoch {epoch} (best epoch: {best_epoch}).")
                break

    if best_state is not None:
        model.load_state_dict(best_state)

    model.eval()
    preds_all: list[int] = []
    y_all: list[int] = []

    with torch.no_grad():
        for xb, yb in test_loader:
            xb = xb.to(device)
            logits = model(xb)
            preds = torch.argmax(logits, dim=1).cpu().numpy().tolist()
            preds_all.extend(preds)
            y_all.extend(yb.numpy().tolist())

    class_names = [str(c) for c in encoder.classes_.tolist()]
    report = classification_report(y_all, preds_all, target_names=class_names, digits=4, zero_division=0)
    cm = confusion_matrix(y_all, preds_all)

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    model_path = out_dir / "cnn_transfer_resnet18.pth"
    classes_path = out_dir / "classes.npy"
    report_path = out_dir / "classification_report.txt"
    cm_png = out_dir / "confusion_matrix.png"
    curves_png = out_dir / "training_curves.png"

    torch.save(
        {
            "model_state_dict": model.state_dict(),
            "num_classes": len(encoder.classes_),
            "class_names": encoder.classes_.tolist(),
            "use_pretrained": use_pretrained,
            "input_channels": 1,
            "arch": "resnet18",
        },
        model_path,
    )
    np.save(classes_path, encoder.classes_)

    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)

    save_confusion_matrix(cm, class_names, cm_png, title="Transfer CNN Confusion Matrix")
    save_training_curves(history, curves_png)

    print("Training complete.")
    print(f"Best epoch: {best_epoch}")
    print(f"Model: {model_path}")
    print(f"Classes: {classes_path}")
    print(f"Report: {report_path}")
    print(f"Confusion matrix: {cm_png}")
    print(f"Curves: {curves_png}")
    print("\nClassification Report:\n")
    print(report)


if __name__ == "__main__":
    main()
