from __future__ import annotations

import argparse
import csv
import json
from math import ceil
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from sklearn.metrics import average_precision_score
from sklearn.model_selection import GroupShuffleSplit, train_test_split
from sklearn.preprocessing import LabelEncoder
from torch.utils.data import DataLoader, Dataset


class MultiTaskDataset(Dataset):
    def __init__(self, X: np.ndarray, y_onsets: np.ndarray, y_frames: np.ndarray):
        self.X = torch.from_numpy(X).float()
        self.y_onsets = torch.from_numpy(y_onsets).float()
        self.y_frames = torch.from_numpy(y_frames).float()

    def __len__(self) -> int:
        return len(self.X)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        return self.X[idx], self.y_onsets[idx], self.y_frames[idx]


class MultiTaskFineTuneModel(nn.Module):
    def __init__(self, num_outputs: int):
        super().__init__()
        from torchvision import models

        backbone = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)

        old_conv = backbone.conv1
        backbone.conv1 = nn.Conv2d(
            1,
            old_conv.out_channels,
            kernel_size=old_conv.kernel_size,
            stride=old_conv.stride,
            padding=old_conv.padding,
            bias=False,
        )
        with torch.no_grad():
            backbone.conv1.weight.copy_(old_conv.weight.mean(dim=1, keepdim=True))

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


def freeze_backbone(model: MultiTaskFineTuneModel) -> None:
    for p in model.backbone.parameters():
        p.requires_grad = False


def unfreeze_backbone(model: MultiTaskFineTuneModel) -> None:
    for p in model.backbone.parameters():
        p.requires_grad = True


def prepare_inputs(X: np.ndarray) -> np.ndarray:
    X = X.astype(np.float32)
    X = np.log1p(np.maximum(X, 0.0))

    mean = X.mean(axis=(1, 2), keepdims=True)
    std = X.std(axis=(1, 2), keepdims=True) + 1e-6
    X = (X - mean) / std
    return X[:, None, :, :]


def split_indices(
    n_samples: int,
    labels_for_stratify: np.ndarray | None,
    test_size: float,
    val_size: float,
    seed: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    if n_samples < 3:
        raise SystemExit("Need at least 3 samples for train/val/test split.")

    test_count = max(1, min(n_samples - 2, int(ceil(n_samples * test_size))))
    test_fraction = test_count / n_samples

    indices = np.arange(n_samples)
    stratify_all = labels_for_stratify if labels_for_stratify is not None else None

    train_val_idx, test_idx = train_test_split(
        indices,
        test_size=test_fraction,
        random_state=seed,
        stratify=stratify_all,
    )

    train_val_count = len(train_val_idx)
    val_count = max(1, min(train_val_count - 1, int(ceil(train_val_count * val_size))))
    val_fraction = val_count / train_val_count

    stratify_train_val = None
    if labels_for_stratify is not None:
        stratify_train_val = labels_for_stratify[train_val_idx]

    train_idx, val_idx = train_test_split(
        train_val_idx,
        test_size=val_fraction,
        random_state=seed,
        stratify=stratify_train_val,
    )

    return train_idx, val_idx, test_idx


def split_indices_grouped(
    n_samples: int,
    groups: np.ndarray,
    test_size: float,
    val_size: float,
    seed: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    if n_samples < 3:
        raise SystemExit("Need at least 3 samples for train/val/test split.")
    if len(groups) != n_samples:
        raise SystemExit("Group ids rows must match sample rows.")

    unique_groups = np.unique(groups)
    if len(unique_groups) < 3:
        raise SystemExit("Need at least 3 unique groups for grouped train/val/test split.")

    test_count = max(1, min(n_samples - 2, int(ceil(n_samples * test_size))))
    test_fraction = test_count / n_samples

    indices = np.arange(n_samples)
    first_splitter = GroupShuffleSplit(n_splits=1, test_size=test_fraction, random_state=seed)
    train_val_rel, test_rel = next(first_splitter.split(indices, groups=groups))
    train_val_idx = indices[train_val_rel]
    test_idx = indices[test_rel]

    train_val_count = len(train_val_idx)
    if train_val_count < 2:
        raise SystemExit("Grouped split left fewer than 2 samples for train/val.")

    val_count = max(1, min(train_val_count - 1, int(ceil(train_val_count * val_size))))
    val_fraction = val_count / train_val_count

    second_splitter = GroupShuffleSplit(n_splits=1, test_size=val_fraction, random_state=seed)
    tv_groups = groups[train_val_idx]
    train_rel, val_rel = next(second_splitter.split(train_val_idx, groups=tv_groups))

    train_idx = train_val_idx[train_rel]
    val_idx = train_val_idx[val_rel]
    return train_idx, val_idx, test_idx


def parse_group_ids_from_segment_names(segment_names: np.ndarray) -> np.ndarray:
    groups: list[str] = []
    for name in segment_names.astype(str).tolist():
        stem = Path(name).stem
        parts = stem.split("_")
        if len(parts) >= 4 and parts[0].startswith("s") and parts[1].startswith("f") and parts[-1].startswith("take"):
            string_id = parts[0]
            variation = "_".join(parts[2:-1])
            take = parts[-1]
            groups.append(f"{string_id}_{variation}_{take}")
        else:
            # Fallback keeps deterministic grouping when names do not follow expected transfer format.
            groups.append(stem)
    return np.array(groups, dtype=object)


def load_index_array(path: Path, n_samples: int, name: str) -> np.ndarray:
    if not path.exists():
        raise SystemExit(f"{name} indices not found: {path}")
    arr = np.load(path, allow_pickle=False)
    idx = np.asarray(arr, dtype=np.int64).reshape(-1)
    if idx.size == 0:
        raise SystemExit(f"{name} indices are empty: {path}")
    if np.any(idx < 0) or np.any(idx >= n_samples):
        raise SystemExit(f"{name} indices contain out-of-range values for n_samples={n_samples}: {path}")
    if np.unique(idx).size != idx.size:
        raise SystemExit(f"{name} indices contain duplicates: {path}")
    return idx


def run_epoch(
    model: MultiTaskFineTuneModel,
    loader: DataLoader,
    onset_criterion: nn.Module,
    frame_criterion: nn.Module,
    optimizer: torch.optim.Optimizer | None,
    device: torch.device,
    frame_loss_weight: float,
) -> tuple[float, float, float]:
    is_train = optimizer is not None
    model.train(is_train)

    total_onset = 0.0
    total_frame = 0.0
    total = 0.0

    for xb, y_onsets, y_frames in loader:
        xb = xb.to(device)
        y_onsets = y_onsets.to(device)
        y_frames = y_frames.to(device)

        if is_train:
            optimizer.zero_grad()

        pred_onsets, pred_frames = model(xb)
        onset_loss = onset_criterion(pred_onsets, y_onsets)
        frame_loss = frame_criterion(pred_frames, y_frames)
        loss = onset_loss + frame_loss_weight * frame_loss

        if is_train:
            loss.backward()
            optimizer.step()

        total_onset += float(onset_loss.item())
        total_frame += float(frame_loss.item())
        total += float(loss.item())

    denom = max(1, len(loader))
    return total_onset / denom, total_frame / denom, total / denom


def collect_logits(
    model: MultiTaskFineTuneModel,
    loader: DataLoader,
    device: torch.device,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    model.eval()
    onset_logits: list[np.ndarray] = []
    frame_logits: list[np.ndarray] = []
    onset_true: list[np.ndarray] = []
    frame_true: list[np.ndarray] = []

    with torch.no_grad():
        for xb, y_onsets, y_frames in loader:
            xb = xb.to(device)
            pred_onsets, pred_frames = model(xb)

            onset_logits.append(pred_onsets.detach().cpu().numpy())
            frame_logits.append(pred_frames.detach().cpu().numpy())
            onset_true.append(y_onsets.numpy())
            frame_true.append(y_frames.numpy())

    return (
        np.concatenate(onset_logits, axis=0),
        np.concatenate(frame_logits, axis=0),
        np.concatenate(onset_true, axis=0),
        np.concatenate(frame_true, axis=0),
    )


def sigmoid_np(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def tune_thresholds_per_class(y_true: np.ndarray, probs: np.ndarray, grid: np.ndarray) -> np.ndarray:
    n_classes = y_true.shape[1]
    thresholds = np.full((n_classes,), 0.5, dtype=np.float32)
    eps = 1e-8

    for c in range(n_classes):
        y_c = y_true[:, c] >= 0.5
        p_c = probs[:, c]
        if int(np.sum(y_c)) == 0:
            thresholds[c] = 0.5
            continue

        best_t = 0.5
        best_f1 = -1.0
        for t in grid.tolist():
            pred = p_c >= float(t)
            tp = float(np.sum(pred & y_c))
            fp = float(np.sum(pred & (~y_c)))
            fn = float(np.sum((~pred) & y_c))

            precision = tp / (tp + fp + eps)
            recall = tp / (tp + fn + eps)
            f1 = 2.0 * precision * recall / (precision + recall + eps)
            if f1 > best_f1:
                best_f1 = f1
                best_t = float(t)

        thresholds[c] = best_t

    return thresholds


def compute_binary_head_metrics(y_true: np.ndarray, probs: np.ndarray, thresholds: np.ndarray) -> dict[str, float]:
    eps = 1e-8
    y_bool = y_true >= 0.5
    pred_bool = probs >= thresholds[None, :]

    tp_c = np.sum(pred_bool & y_bool, axis=0).astype(np.float64)
    fp_c = np.sum(pred_bool & (~y_bool), axis=0).astype(np.float64)
    fn_c = np.sum((~pred_bool) & y_bool, axis=0).astype(np.float64)
    support_c = np.sum(y_bool, axis=0).astype(np.float64)

    precision_c = tp_c / (tp_c + fp_c + eps)
    recall_c = tp_c / (tp_c + fn_c + eps)
    f1_c = 2.0 * precision_c * recall_c / (precision_c + recall_c + eps)

    tp = float(np.sum(tp_c))
    fp = float(np.sum(fp_c))
    fn = float(np.sum(fn_c))
    precision_micro = tp / (tp + fp + eps)
    recall_micro = tp / (tp + fn + eps)
    f1_micro = 2.0 * precision_micro * recall_micro / (precision_micro + recall_micro + eps)

    weights = support_c / (float(np.sum(support_c)) + eps)
    f1_weighted = float(np.sum(f1_c * weights))
    precision_weighted = float(np.sum(precision_c * weights))
    recall_weighted = float(np.sum(recall_c * weights))

    pr_auc_vals: list[float] = []
    for c in range(y_true.shape[1]):
        y_c = y_true[:, c]
        if np.sum(y_c) == 0:
            continue
        pr_auc_vals.append(float(average_precision_score(y_c, probs[:, c])))

    pr_auc_macro = float(np.mean(pr_auc_vals)) if pr_auc_vals else 0.0

    return {
        "precision_micro": float(precision_micro),
        "recall_micro": float(recall_micro),
        "f1_micro": float(f1_micro),
        "precision_macro": float(np.mean(precision_c)),
        "recall_macro": float(np.mean(recall_c)),
        "f1_macro": float(np.mean(f1_c)),
        "precision_weighted": precision_weighted,
        "recall_weighted": recall_weighted,
        "f1_weighted": f1_weighted,
        "pr_auc_macro": pr_auc_macro,
    }


def to_multitask_targets_from_labels(labels_text: np.ndarray) -> tuple[np.ndarray, np.ndarray, list[str]]:
    encoder = LabelEncoder()
    y = encoder.fit_transform(labels_text)
    num_classes = len(encoder.classes_)

    y_frames = np.zeros((len(y), num_classes), dtype=np.float32)
    y_frames[np.arange(len(y)), y] = 1.0

    # Scaffold fallback: when true onset/frame matrices are unavailable,
    # use class-onehot as placeholder for both heads.
    y_onsets = y_frames.copy()
    return y_onsets, y_frames, [str(c) for c in encoder.classes_.tolist()]


def maybe_load_backbone_weights(model: MultiTaskFineTuneModel, checkpoint_path: Path | None) -> None:
    if checkpoint_path is None:
        return
    if not checkpoint_path.exists():
        raise SystemExit(f"Checkpoint not found: {checkpoint_path}")

    ckpt = torch.load(checkpoint_path, map_location="cpu")
    if isinstance(ckpt, dict) and "model_state_dict" in ckpt:
        state = ckpt["model_state_dict"]
    elif isinstance(ckpt, dict):
        state = ckpt
    else:
        raise SystemExit("Unsupported checkpoint format. Expected state_dict-like dictionary.")

    model.backbone.load_state_dict(state, strict=False)


def align_features_to_segment_order(
    X: np.ndarray,
    feature_names_path: Path,
    segment_order_path: Path,
) -> np.ndarray:
    if not feature_names_path.exists():
        raise SystemExit(f"Feature names not found: {feature_names_path}")
    if not segment_order_path.exists():
        raise SystemExit(f"Segment order not found: {segment_order_path}")

    feature_names = np.load(feature_names_path, allow_pickle=True).astype(str)
    segment_order = np.load(segment_order_path, allow_pickle=True).astype(str)

    if len(feature_names) != X.shape[0]:
        raise SystemExit("Feature names rows must match feature rows.")

    index = {name: i for i, name in enumerate(feature_names.tolist())}
    missing = [name for name in segment_order.tolist() if name not in index]
    if missing:
        raise SystemExit(
            "Some target segment names are missing in features. "
            f"Missing count: {len(missing)}; sample: {missing[:5]}"
        )

    aligned = X[[index[name] for name in segment_order.tolist()]]
    print(
        "Aligned features to segment order: "
        f"{X.shape[0]} -> {aligned.shape[0]} rows "
        f"using {feature_names_path.name} and {segment_order_path.name}"
    )
    return aligned


def save_history_csv(history_rows: list[dict[str, float]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "epoch",
            "train_onset_bce",
            "train_frame_bce",
            "train_total",
            "val_onset_bce",
            "val_frame_bce",
            "val_total",
            "val_onset_f1_weighted",
            "val_frame_f1_weighted",
            "lr",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(history_rows)


def compute_pos_weight(y: np.ndarray, max_pos_weight: float = 20.0) -> np.ndarray:
    pos = np.sum(y >= 0.5, axis=0).astype(np.float64)
    neg = float(y.shape[0]) - pos
    pos_weight = (neg + 1e-8) / (pos + 1e-8)
    return np.clip(pos_weight, 1.0, max_pos_weight).astype(np.float32)


def main() -> None:
    parser = argparse.ArgumentParser(description="Basic Pitch fine-tuning scaffold (PyTorch, BCE multi-head)")
    parser.add_argument("--features", required=True, help="Path to X_mel.npy or similar [N,H,W]")
    parser.add_argument("--labels", default=None, help="Optional y_labels.npy for fallback target generation")
    parser.add_argument(
        "--onsets",
        default=None,
        help=(
            "Optional onset target matrix .npy [N,C]. "
            "Use data exported by prepare_transfer_chromatic_dataset.py (y_onsets_transfer.npy)."
        ),
    )
    parser.add_argument(
        "--frames",
        default=None,
        help=(
            "Optional frame target matrix .npy [N,C]. "
            "Use data exported by prepare_transfer_chromatic_dataset.py (y_frames_transfer.npy)."
        ),
    )
    parser.add_argument(
        "--feature-names",
        default=None,
        help="Optional file_names.npy for reordering features to match segment order",
    )
    parser.add_argument(
        "--segment-order",
        default=None,
        help="Optional segment_order_transfer.npy with desired target row ordering",
    )
    parser.add_argument(
        "--strict-alignment",
        action="store_true",
        help=(
            "Fail on feature/target row mismatch unless explicit --feature-names and --segment-order "
            "are provided for deterministic reordering"
        ),
    )
    parser.add_argument("--basic-pitch-checkpoint", default=None, help="Optional transferred checkpoint for backbone")
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--val-size", type=float, default=0.2)
    parser.add_argument("--train-indices", default=None, help="Optional .npy train index array")
    parser.add_argument("--val-indices", default=None, help="Optional .npy val index array")
    parser.add_argument("--test-indices", default=None, help="Optional .npy test index array")
    parser.add_argument("--group-split", action="store_true", help="Use group-aware split to reduce leakage")
    parser.add_argument("--group-ids", default=None, help="Optional group id array (.npy) aligned to training rows")
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--freeze-epochs", type=int, default=5)
    parser.add_argument("--early-stopping-patience", type=int, default=5)
    parser.add_argument("--early-stopping-min-delta", type=float, default=1e-4)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--fine-tune-lr", type=float, default=1e-4)
    parser.add_argument("--frame-loss-weight", type=float, default=1.0)
    parser.add_argument(
        "--pos-weight-mode",
        choices=["none", "balanced"],
        default="balanced",
        help="Class imbalance handling mode for BCEWithLogitsLoss",
    )
    parser.add_argument("--max-pos-weight", type=float, default=20.0)
    parser.add_argument("--threshold-grid-size", type=int, default=17)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out-dir", default="models/trained_models/basic_pitch_finetune")
    args = parser.parse_args()

    np.random.seed(args.seed)
    torch.manual_seed(args.seed)

    features_path = Path(args.features).resolve()
    if not features_path.exists():
        raise SystemExit(f"Features not found: {features_path}")

    X = np.load(features_path)
    X = prepare_inputs(X)

    y_onsets: np.ndarray
    y_frames: np.ndarray
    class_names: list[str]
    stratify_labels: np.ndarray | None = None
    sample_names_for_groups: np.ndarray | None = None

    if args.onsets and args.frames:
        y_onsets = np.load(Path(args.onsets).resolve()).astype(np.float32)
        y_frames = np.load(Path(args.frames).resolve()).astype(np.float32)
        if y_onsets.shape != y_frames.shape:
            raise SystemExit("Onset and frame targets must have the same shape [N,C].")
        if y_onsets.shape[0] != X.shape[0]:
            if args.strict_alignment:
                if not args.feature_names or not args.segment_order:
                    raise SystemExit(
                        "--strict-alignment enabled: provide both --feature-names and --segment-order "
                        "to resolve feature/target row mismatch deterministically."
                    )
                feature_names_path = Path(args.feature_names).resolve()
                segment_order_path = Path(args.segment_order).resolve()
                X = align_features_to_segment_order(X, feature_names_path, segment_order_path)
                sample_names_for_groups = np.load(segment_order_path, allow_pickle=True).astype(str)
            else:
                feature_names_path = Path(args.feature_names).resolve() if args.feature_names else features_path.parent / "file_names.npy"
                segment_order_path = (
                    Path(args.segment_order).resolve()
                    if args.segment_order
                    else Path(args.onsets).resolve().parent / "segment_order_transfer.npy"
                )

                if feature_names_path.exists() and segment_order_path.exists():
                    X = align_features_to_segment_order(X, feature_names_path, segment_order_path)
                    sample_names_for_groups = np.load(segment_order_path, allow_pickle=True).astype(str)
                elif feature_names_path.exists():
                    sample_names_for_groups = np.load(feature_names_path, allow_pickle=True).astype(str)

            if y_onsets.shape[0] != X.shape[0]:
                raise SystemExit("Target rows must match feature rows.")

        if sample_names_for_groups is None and args.segment_order and Path(args.segment_order).resolve().exists():
            sample_names_for_groups = np.load(Path(args.segment_order).resolve(), allow_pickle=True).astype(str)
        class_names = [f"bin_{i}" for i in range(y_onsets.shape[1])]
    elif args.labels:
        labels = np.load(Path(args.labels).resolve(), allow_pickle=True)
        if labels.shape[0] != X.shape[0]:
            raise SystemExit("Labels rows must match feature rows.")
        y_onsets, y_frames, class_names = to_multitask_targets_from_labels(labels)
        stratify_labels = LabelEncoder().fit_transform(labels)
        if args.feature_names and Path(args.feature_names).resolve().exists():
            sample_names_for_groups = np.load(Path(args.feature_names).resolve(), allow_pickle=True).astype(str)
    else:
        raise SystemExit("Provide either --onsets and --frames, or --labels fallback.")

    has_explicit_split = bool(args.train_indices and args.val_indices and args.test_indices)
    if has_explicit_split:
        train_idx = load_index_array(Path(args.train_indices).resolve(), X.shape[0], "Train")
        val_idx = load_index_array(Path(args.val_indices).resolve(), X.shape[0], "Val")
        test_idx = load_index_array(Path(args.test_indices).resolve(), X.shape[0], "Test")

        overlap = np.intersect1d(train_idx, val_idx).size + np.intersect1d(train_idx, test_idx).size + np.intersect1d(val_idx, test_idx).size
        if overlap > 0:
            raise SystemExit("Explicit split indices overlap across train/val/test.")

        covered = np.unique(np.concatenate([train_idx, val_idx, test_idx]))
        if covered.size != X.shape[0]:
            raise SystemExit("Explicit split indices must cover all samples exactly once.")

        print("Using explicit split indices from --train-indices/--val-indices/--test-indices.")
    elif args.group_split:
        if args.group_ids:
            group_ids = np.load(Path(args.group_ids).resolve(), allow_pickle=True)
        elif sample_names_for_groups is not None:
            group_ids = parse_group_ids_from_segment_names(sample_names_for_groups)
        else:
            raise SystemExit("--group-split requires --group-ids or aligned sample names via --segment-order/--feature-names.")

        if len(group_ids) != X.shape[0]:
            raise SystemExit("Group ids rows must match feature rows.")

        train_idx, val_idx, test_idx = split_indices_grouped(
            n_samples=X.shape[0],
            groups=np.asarray(group_ids),
            test_size=args.test_size,
            val_size=args.val_size,
            seed=args.seed,
        )
        print(f"Grouped split enabled. Unique groups: {len(np.unique(group_ids))}")
    else:
        train_idx, val_idx, test_idx = split_indices(
            n_samples=X.shape[0],
            labels_for_stratify=stratify_labels,
            test_size=args.test_size,
            val_size=args.val_size,
            seed=args.seed,
        )

    print(
        f"Split sizes: train={len(train_idx)} val={len(val_idx)} test={len(test_idx)} "
        f"(test={len(test_idx)/len(X):.2%} of full set)"
    )

    train_ds = MultiTaskDataset(X[train_idx], y_onsets[train_idx], y_frames[train_idx])
    val_ds = MultiTaskDataset(X[val_idx], y_onsets[val_idx], y_frames[val_idx])
    test_ds = MultiTaskDataset(X[test_idx], y_onsets[test_idx], y_frames[test_idx])

    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True)
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False)
    test_loader = DataLoader(test_ds, batch_size=args.batch_size, shuffle=False)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = MultiTaskFineTuneModel(num_outputs=y_onsets.shape[1]).to(device)

    maybe_load_backbone_weights(
        model=model,
        checkpoint_path=Path(args.basic_pitch_checkpoint).resolve() if args.basic_pitch_checkpoint else None,
    )

    freeze_backbone(model)

    if args.pos_weight_mode == "balanced":
        onset_pw = torch.from_numpy(compute_pos_weight(y_onsets[train_idx], args.max_pos_weight)).to(device)
        frame_pw = torch.from_numpy(compute_pos_weight(y_frames[train_idx], args.max_pos_weight)).to(device)
        onset_criterion = nn.BCEWithLogitsLoss(pos_weight=onset_pw)
        frame_criterion = nn.BCEWithLogitsLoss(pos_weight=frame_pw)
        print("Using balanced BCE pos_weight for onset/frame heads.")
    else:
        onset_criterion = nn.BCEWithLogitsLoss()
        frame_criterion = nn.BCEWithLogitsLoss()

    optimizer = torch.optim.AdamW(
        [p for p in model.parameters() if p.requires_grad],
        lr=args.lr,
        weight_decay=args.weight_decay,
    )
    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer,
        mode="min",
        factor=0.5,
        patience=3,
        min_lr=1e-6,
    )

    history_rows: list[dict[str, float]] = []
    best_val = float("inf")
    best_state: dict[str, torch.Tensor] | None = None
    best_epoch = 0
    no_improve_epochs = 0

    for epoch in range(1, args.epochs + 1):
        if epoch == args.freeze_epochs + 1:
            unfreeze_backbone(model)
            optimizer = torch.optim.AdamW(model.parameters(), lr=args.fine_tune_lr, weight_decay=args.weight_decay)
            scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
                optimizer,
                mode="min",
                factor=0.5,
                patience=3,
                min_lr=1e-6,
            )

        train_onset, train_frame, train_total = run_epoch(
            model,
            train_loader,
            onset_criterion,
            frame_criterion,
            optimizer,
            device,
            args.frame_loss_weight,
        )
        val_onset, val_frame, val_total = run_epoch(
            model,
            val_loader,
            onset_criterion,
            frame_criterion,
            None,
            device,
            args.frame_loss_weight,
        )

        scheduler.step(val_total)
        lr = float(optimizer.param_groups[0]["lr"])

        val_onset_logits, val_frame_logits, val_onset_true, val_frame_true = collect_logits(model, val_loader, device)
        val_onset_probs = sigmoid_np(val_onset_logits)
        val_frame_probs = sigmoid_np(val_frame_logits)
        threshold_grid = np.linspace(0.1, 0.9, args.threshold_grid_size, dtype=np.float32)
        val_onset_thr = tune_thresholds_per_class(val_onset_true, val_onset_probs, threshold_grid)
        val_frame_thr = tune_thresholds_per_class(val_frame_true, val_frame_probs, threshold_grid)
        val_onset_metrics = compute_binary_head_metrics(val_onset_true, val_onset_probs, val_onset_thr)
        val_frame_metrics = compute_binary_head_metrics(val_frame_true, val_frame_probs, val_frame_thr)

        history_rows.append(
            {
                "epoch": float(epoch),
                "train_onset_bce": train_onset,
                "train_frame_bce": train_frame,
                "train_total": train_total,
                "val_onset_bce": val_onset,
                "val_frame_bce": val_frame,
                "val_total": val_total,
                "val_onset_f1_weighted": float(val_onset_metrics["f1_weighted"]),
                "val_frame_f1_weighted": float(val_frame_metrics["f1_weighted"]),
                "lr": lr,
            }
        )

        print(
            f"Epoch {epoch:02d}/{args.epochs} | "
            f"train_onset={train_onset:.4f} train_frame={train_frame:.4f} train_total={train_total:.4f} | "
            f"val_onset={val_onset:.4f} val_frame={val_frame:.4f} val_total={val_total:.4f} | "
            f"val_onset_f1w={val_onset_metrics['f1_weighted']:.4f} val_frame_f1w={val_frame_metrics['f1_weighted']:.4f} | "
            f"lr={lr:.6f}"
        )

        if val_total < (best_val - args.early_stopping_min_delta):
            best_val = val_total
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}
            best_epoch = epoch
            no_improve_epochs = 0
        else:
            no_improve_epochs += 1

        if no_improve_epochs >= args.early_stopping_patience:
            print(
                f"Early stopping at epoch {epoch} (best epoch={best_epoch}, best val_total={best_val:.4f}, "
                f"patience={args.early_stopping_patience})."
            )
            break

    if best_state is not None:
        model.load_state_dict(best_state)

    test_onset, test_frame, test_total = run_epoch(
        model,
        test_loader,
        onset_criterion,
        frame_criterion,
        None,
        device,
        args.frame_loss_weight,
    )

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    model_path = out_dir / "basic_pitch_finetune_scaffold.pth"
    history_path = out_dir / "training_history.csv"
    classes_path = out_dir / "classes.npy"
    thresholds_path = out_dir / "thresholds.json"
    metrics_path = out_dir / "metrics_summary.json"
    split_manifest_path = out_dir / "split_manifest.json"

    val_onset_logits, val_frame_logits, val_onset_true, val_frame_true = collect_logits(model, val_loader, device)
    test_onset_logits, test_frame_logits, test_onset_true, test_frame_true = collect_logits(model, test_loader, device)

    val_onset_probs = sigmoid_np(val_onset_logits)
    val_frame_probs = sigmoid_np(val_frame_logits)
    test_onset_probs = sigmoid_np(test_onset_logits)
    test_frame_probs = sigmoid_np(test_frame_logits)

    threshold_grid = np.linspace(0.1, 0.9, args.threshold_grid_size, dtype=np.float32)
    onset_thresholds = tune_thresholds_per_class(val_onset_true, val_onset_probs, threshold_grid)
    frame_thresholds = tune_thresholds_per_class(val_frame_true, val_frame_probs, threshold_grid)

    val_onset_metrics = compute_binary_head_metrics(val_onset_true, val_onset_probs, onset_thresholds)
    val_frame_metrics = compute_binary_head_metrics(val_frame_true, val_frame_probs, frame_thresholds)
    test_onset_metrics = compute_binary_head_metrics(test_onset_true, test_onset_probs, onset_thresholds)
    test_frame_metrics = compute_binary_head_metrics(test_frame_true, test_frame_probs, frame_thresholds)

    torch.save(
        {
            "model_state_dict": model.state_dict(),
            "num_outputs": y_onsets.shape[1],
            "class_names": class_names,
            "arch": "resnet18_multitask_heads_scaffold",
            "bce_heads": ["onsets", "frames"],
            "note": "Scaffold for Basic Pitch head fine-tuning workflow in PyTorch.",
            "best_epoch": best_epoch,
        },
        model_path,
    )
    np.save(classes_path, np.array(class_names, dtype=object))
    save_history_csv(history_rows, history_path)

    with open(thresholds_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "onset_thresholds": onset_thresholds.tolist(),
                "frame_thresholds": frame_thresholds.tolist(),
            },
            f,
            indent=2,
        )

    with open(metrics_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "best_val_total": float(best_val),
                "best_epoch": int(best_epoch),
                "split_sizes": {
                    "train": int(len(train_idx)),
                    "val": int(len(val_idx)),
                    "test": int(len(test_idx)),
                },
                "test_onset_bce": float(test_onset),
                "test_frame_bce": float(test_frame),
                "test_total": float(test_total),
                "val_metrics": {
                    "onset": val_onset_metrics,
                    "frame": val_frame_metrics,
                },
                "test_metrics": {
                    "onset": test_onset_metrics,
                    "frame": test_frame_metrics,
                },
            },
            f,
            indent=2,
        )

    with open(split_manifest_path, "w", encoding="utf-8") as f:
        json.dump(
            {
                "n_samples": int(X.shape[0]),
                "train_indices": train_idx.tolist(),
                "val_indices": val_idx.tolist(),
                "test_indices": test_idx.tolist(),
            },
            f,
            indent=2,
        )

    print("Training complete.")
    print(f"Best epoch: {best_epoch}")
    print(f"Best val_total: {best_val:.4f}")
    print(f"Test onset BCE: {test_onset:.4f}")
    print(f"Test frame BCE: {test_frame:.4f}")
    print(f"Test total: {test_total:.4f}")
    print(f"Test onset F1 weighted: {test_onset_metrics['f1_weighted']:.4f}")
    print(f"Test frame F1 weighted: {test_frame_metrics['f1_weighted']:.4f}")
    print(f"Test onset PR-AUC macro: {test_onset_metrics['pr_auc_macro']:.4f}")
    print(f"Test frame PR-AUC macro: {test_frame_metrics['pr_auc_macro']:.4f}")
    print(f"Model: {model_path}")
    print(f"History: {history_path}")
    print(f"Classes: {classes_path}")
    print(f"Thresholds: {thresholds_path}")
    print(f"Metrics: {metrics_path}")
    print(f"Split manifest: {split_manifest_path}")


if __name__ == "__main__":
    main()
