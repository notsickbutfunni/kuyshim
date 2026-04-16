from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from sklearn.model_selection import GroupKFold, GroupShuffleSplit


def _load_array(path: Path, allow_pickle: bool = False) -> np.ndarray:
    if not path.exists():
        raise SystemExit(f"Missing file: {path}")
    return np.load(path, allow_pickle=allow_pickle)


def _mean_std(values: list[float]) -> dict[str, float]:
    if not values:
        return {"mean": 0.0, "std": 0.0}
    arr = np.asarray(values, dtype=np.float64)
    return {"mean": float(np.mean(arr)), "std": float(np.std(arr))}


def main() -> None:
    parser = argparse.ArgumentParser(description="Run grouped K-fold x multi-seed CV for Basic Pitch fine-tuning")
    parser.add_argument("--features", required=True)
    parser.add_argument("--onsets", required=True)
    parser.add_argument("--frames", required=True)
    parser.add_argument("--feature-names", required=True)
    parser.add_argument("--segment-order", required=True)
    parser.add_argument("--group-ids", required=True, help=".npy group IDs aligned to segment order")
    parser.add_argument("--folds", type=int, default=5)
    parser.add_argument("--seeds", nargs="+", type=int, default=[42, 52, 62])
    parser.add_argument("--val-size", type=float, default=0.2)
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--freeze-epochs", type=int, default=5)
    parser.add_argument("--batch-size", type=int, default=8)
    parser.add_argument("--early-stopping-patience", type=int, default=5)
    parser.add_argument("--early-stopping-min-delta", type=float, default=1e-4)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--fine-tune-lr", type=float, default=1e-4)
    parser.add_argument("--weight-decay", type=float, default=1e-4)
    parser.add_argument("--frame-loss-weight", type=float, default=1.0)
    parser.add_argument("--pos-weight-mode", choices=["none", "balanced"], default="balanced")
    parser.add_argument("--max-pos-weight", type=float, default=20.0)
    parser.add_argument("--threshold-grid-size", type=int, default=17)
    parser.add_argument("--trainer-script", default="ml/scripts/train_basic_pitch_finetune.py")
    parser.add_argument("--out-dir", default="ml/models/trained_models/basic_pitch_finetune_cv")
    args = parser.parse_args()

    features_path = Path(args.features).resolve()
    onsets_path = Path(args.onsets).resolve()
    frames_path = Path(args.frames).resolve()
    feature_names_path = Path(args.feature_names).resolve()
    segment_order_path = Path(args.segment_order).resolve()
    group_ids_path = Path(args.group_ids).resolve()
    trainer_script = Path(args.trainer_script).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    X = _load_array(features_path)
    y_onsets = _load_array(onsets_path)
    y_frames = _load_array(frames_path)
    if y_onsets.shape != y_frames.shape:
        raise SystemExit("Onset/frame targets must have identical shape.")

    groups = _load_array(group_ids_path, allow_pickle=True).astype(str)
    if len(groups) != y_onsets.shape[0]:
        raise SystemExit("group_ids length must match target rows.")

    n_samples = int(y_onsets.shape[0])
    if n_samples < args.folds:
        raise SystemExit(f"Not enough samples ({n_samples}) for folds={args.folds}")

    indices = np.arange(n_samples)
    gkf = GroupKFold(n_splits=args.folds)
    fold_pairs = list(gkf.split(indices, groups=groups))

    run_records: list[dict[str, object]] = []

    for seed in args.seeds:
        for fold_idx, (train_val_idx, test_idx) in enumerate(fold_pairs, start=1):
            train_val_groups = groups[train_val_idx]
            split = GroupShuffleSplit(n_splits=1, test_size=args.val_size, random_state=seed + fold_idx)
            tr_rel, va_rel = next(split.split(train_val_idx, groups=train_val_groups))
            train_idx = train_val_idx[tr_rel]
            val_idx = train_val_idx[va_rel]

            run_name = f"seed_{seed}_fold_{fold_idx}"
            run_dir = out_dir / run_name
            run_dir.mkdir(parents=True, exist_ok=True)

            np.save(run_dir / "train_idx.npy", train_idx.astype(np.int64))
            np.save(run_dir / "val_idx.npy", val_idx.astype(np.int64))
            np.save(run_dir / "test_idx.npy", test_idx.astype(np.int64))

            cmd = [
                sys.executable,
                str(trainer_script),
                "--features",
                str(features_path),
                "--onsets",
                str(onsets_path),
                "--frames",
                str(frames_path),
                "--feature-names",
                str(feature_names_path),
                "--segment-order",
                str(segment_order_path),
                "--strict-alignment",
                "--train-indices",
                str(run_dir / "train_idx.npy"),
                "--val-indices",
                str(run_dir / "val_idx.npy"),
                "--test-indices",
                str(run_dir / "test_idx.npy"),
                "--epochs",
                str(args.epochs),
                "--freeze-epochs",
                str(args.freeze_epochs),
                "--batch-size",
                str(args.batch_size),
                "--early-stopping-patience",
                str(args.early_stopping_patience),
                "--early-stopping-min-delta",
                str(args.early_stopping_min_delta),
                "--lr",
                str(args.lr),
                "--fine-tune-lr",
                str(args.fine_tune_lr),
                "--weight-decay",
                str(args.weight_decay),
                "--frame-loss-weight",
                str(args.frame_loss_weight),
                "--pos-weight-mode",
                args.pos_weight_mode,
                "--max-pos-weight",
                str(args.max_pos_weight),
                "--threshold-grid-size",
                str(args.threshold_grid_size),
                "--seed",
                str(seed),
                "--out-dir",
                str(run_dir),
            ]

            print(f"Running {run_name} ...")
            completed = subprocess.run(cmd, check=False)
            if completed.returncode != 0:
                raise SystemExit(f"Run failed: {run_name} (exit={completed.returncode})")

            metrics_path = run_dir / "metrics_summary.json"
            if not metrics_path.exists():
                raise SystemExit(f"Missing metrics output: {metrics_path}")

            with open(metrics_path, "r", encoding="utf-8") as f:
                metrics = json.load(f)

            record = {
                "run": run_name,
                "seed": int(seed),
                "fold": int(fold_idx),
                "best_epoch": int(metrics.get("best_epoch", 0)),
                "best_val_total": float(metrics.get("best_val_total", 0.0)),
                "test_total": float(metrics.get("test_total", 0.0)),
                "test_onset_f1_weighted": float(metrics["test_metrics"]["onset"]["f1_weighted"]),
                "test_frame_f1_weighted": float(metrics["test_metrics"]["frame"]["f1_weighted"]),
                "test_onset_pr_auc_macro": float(metrics["test_metrics"]["onset"]["pr_auc_macro"]),
                "test_frame_pr_auc_macro": float(metrics["test_metrics"]["frame"]["pr_auc_macro"]),
            }
            run_records.append(record)

    agg = {
        "num_runs": len(run_records),
        "config": {
            "folds": int(args.folds),
            "seeds": [int(s) for s in args.seeds],
            "epochs": int(args.epochs),
            "freeze_epochs": int(args.freeze_epochs),
            "val_size": float(args.val_size),
            "pos_weight_mode": args.pos_weight_mode,
        },
        "aggregate": {
            "best_val_total": _mean_std([float(r["best_val_total"]) for r in run_records]),
            "test_total": _mean_std([float(r["test_total"]) for r in run_records]),
            "test_onset_f1_weighted": _mean_std([float(r["test_onset_f1_weighted"]) for r in run_records]),
            "test_frame_f1_weighted": _mean_std([float(r["test_frame_f1_weighted"]) for r in run_records]),
            "test_onset_pr_auc_macro": _mean_std([float(r["test_onset_pr_auc_macro"]) for r in run_records]),
            "test_frame_pr_auc_macro": _mean_std([float(r["test_frame_pr_auc_macro"]) for r in run_records]),
        },
        "runs": run_records,
    }

    summary_json = out_dir / "cv_summary.json"
    with open(summary_json, "w", encoding="utf-8") as f:
        json.dump(agg, f, indent=2)

    summary_csv = out_dir / "cv_summary.csv"
    with open(summary_csv, "w", encoding="utf-8") as f:
        f.write(
            "run,seed,fold,best_epoch,best_val_total,test_total,test_onset_f1_weighted,test_frame_f1_weighted,test_onset_pr_auc_macro,test_frame_pr_auc_macro\n"
        )
        for r in run_records:
            f.write(
                f"{r['run']},{r['seed']},{r['fold']},{r['best_epoch']},{r['best_val_total']:.6f},{r['test_total']:.6f},"
                f"{r['test_onset_f1_weighted']:.6f},{r['test_frame_f1_weighted']:.6f},{r['test_onset_pr_auc_macro']:.6f},{r['test_frame_pr_auc_macro']:.6f}\n"
            )

    print(f"Completed grouped CV runs: {len(run_records)}")
    print(f"Summary JSON: {summary_json}")
    print(f"Summary CSV: {summary_csv}")


if __name__ == "__main__":
    main()
