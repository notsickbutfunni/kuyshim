from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def choose_best_run(runs: list[dict[str, float]]) -> dict[str, float]:
    ranked = sorted(
        runs,
        key=lambda r: (
            float(r["test_frame_f1_weighted"]),
            float(r["test_onset_f1_weighted"]),
            -float(r["test_total"]),
            float(r.get("best_epoch", 0)),
        ),
        reverse=True,
    )
    return ranked[0]


def copy_required_artifacts(run_dir: Path, out_dir: Path) -> None:
    required = [
        "basic_pitch_finetune_scaffold.pth",
        "classes.npy",
        "thresholds.json",
        "metrics_summary.json",
        "split_manifest.json",
    ]
    for name in required:
        src = run_dir / name
        if not src.exists():
            raise SystemExit(f"Missing required artifact: {src}")
        shutil.copy2(src, out_dir / name)


def main() -> None:
    parser = argparse.ArgumentParser(description="Pick best CV run and package one-day demo release artifacts")
    parser.add_argument("--cv-summary", default="ml/models/trained_models/basic_pitch_finetune_cv/cv_summary.json")
    parser.add_argument("--runs-root", default="ml/models/trained_models/basic_pitch_finetune_cv")
    parser.add_argument("--out-dir", default="ml/models/release_demo_v1")
    parser.add_argument("--accept-top1", type=float, default=0.45)
    parser.add_argument("--accept-margin", type=float, default=0.10)
    parser.add_argument("--strict-top1", type=float, default=0.50)
    parser.add_argument("--strict-margin", type=float, default=0.12)
    args = parser.parse_args()

    cv_summary_path = Path(args.cv_summary).resolve()
    runs_root = Path(args.runs_root).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    if not cv_summary_path.exists():
        raise SystemExit(f"CV summary not found: {cv_summary_path}")

    with open(cv_summary_path, "r", encoding="utf-8") as f:
        cv = json.load(f)

    runs = cv.get("runs") or []
    if not runs:
        raise SystemExit("No runs found in CV summary.")

    selected = choose_best_run(runs)
    run_name = str(selected["run"])
    run_dir = runs_root / run_name
    if not run_dir.exists():
        raise SystemExit(f"Selected run directory not found: {run_dir}")

    copy_required_artifacts(run_dir, out_dir)

    scripts_out = out_dir / "scripts_snapshot"
    scripts_out.mkdir(parents=True, exist_ok=True)
    for rel in ["ml/scripts/train_basic_pitch_finetune.py", "ml/scripts/run_basic_pitch_grouped_cv.py"]:
        src = Path(rel).resolve()
        if src.exists():
            shutil.copy2(src, scripts_out / src.name)

    ranking = sorted(
        runs,
        key=lambda r: (
            float(r["test_frame_f1_weighted"]),
            float(r["test_onset_f1_weighted"]),
            -float(r["test_total"]),
            float(r.get("best_epoch", 0)),
        ),
        reverse=True,
    )

    summary = {
        "selection_rule": [
            "highest test_frame_f1_weighted",
            "then highest test_onset_f1_weighted",
            "then lower test_total",
            "tie-breaker: later best_epoch",
        ],
        "selected_run": selected,
        "source_run_dir": str(run_dir),
        "confidence_policy": {
            "default": {
                "accept_if_top1_gte": args.accept_top1,
                "accept_if_margin_gte": args.accept_margin,
            },
            "strict_fallback": {
                "accept_if_top1_gte": args.strict_top1,
                "accept_if_margin_gte": args.strict_margin,
            },
        },
        "top5": ranking[:5],
    }

    with open(out_dir / "release_summary.json", "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    with open(out_dir / "release_summary.txt", "w", encoding="utf-8") as f:
        f.write("Release Demo v1\n")
        f.write(f"Selected run: {run_name}\n")
        f.write(f"test_frame_f1_weighted: {selected['test_frame_f1_weighted']:.6f}\n")
        f.write(f"test_onset_f1_weighted: {selected['test_onset_f1_weighted']:.6f}\n")
        f.write(f"test_total: {selected['test_total']:.6f}\n")
        f.write("\nDefault confidence policy:\n")
        f.write(f"  top1 >= {args.accept_top1:.2f}\n")
        f.write(f"  margin(top1-top2) >= {args.accept_margin:.2f}\n")
        f.write("Strict fallback policy:\n")
        f.write(f"  top1 >= {args.strict_top1:.2f}\n")
        f.write(f"  margin(top1-top2) >= {args.strict_margin:.2f}\n")

    print(f"Selected run: {run_name}")
    print(f"Packaged release folder: {out_dir}")
    print(f"Release summary: {out_dir / 'release_summary.json'}")


if __name__ == "__main__":
    main()
