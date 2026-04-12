from __future__ import annotations

import argparse
import csv
from pathlib import Path


TEMPLATE_HEADER = ["clip_path", "expected_label", "pred_label", "top1_prob", "top2_prob"]


def to_float(value: str, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def write_template_csv(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=TEMPLATE_HEADER)
        writer.writeheader()
        writer.writerow(
            {
                "clip_path": "ml/data/demo_clips/sample_001.wav",
                "expected_label": "s1_f0",
                "pred_label": "",
                "top1_prob": "",
                "top2_prob": "",
            }
        )
        writer.writerow(
            {
                "clip_path": "ml/data/demo_clips/sample_002.wav",
                "expected_label": "s1_f1",
                "pred_label": "",
                "top1_prob": "",
                "top2_prob": "",
            }
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate one-day demo acceptance metrics with confidence gating")
    parser.add_argument("--input-csv", required=True, help="CSV with expected_label,pred_label,top1_prob,top2_prob")
    parser.add_argument("--out-csv", default=None, help="Optional annotated output CSV")
    parser.add_argument("--top1-threshold", type=float, default=0.45)
    parser.add_argument("--margin-threshold", type=float, default=0.10)
    parser.add_argument(
        "--init-template-if-missing",
        action="store_true",
        help="If --input-csv is missing, create a template file there and exit",
    )
    args = parser.parse_args()

    input_path = Path(args.input_csv).resolve()
    if not input_path.exists():
        if args.init_template_if_missing:
            write_template_csv(input_path)
            print(f"Template created: {input_path}")
            print("Fill pred_label/top1_prob/top2_prob, then run this command again without template init.")
            return
        raise SystemExit(
            f"Input CSV not found: {input_path}\n"
            "Tip: rerun with --init-template-if-missing to create a starter CSV at this path."
        )

    with open(input_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        raise SystemExit("Input CSV has no rows.")

    total = len(rows)
    accepted = 0
    uncertain = 0
    accepted_correct = 0

    annotated_rows: list[dict[str, str]] = []

    for row in rows:
        expected = (row.get("expected_label") or "").strip()
        pred = (row.get("pred_label") or "").strip()
        top1 = to_float(row.get("top1_prob"), 0.0)
        top2 = to_float(row.get("top2_prob"), 0.0)
        margin = top1 - top2

        is_accepted = (top1 >= args.top1_threshold) and (margin >= args.margin_threshold)
        decision = "accepted" if is_accepted else "uncertain"

        if is_accepted:
            accepted += 1
            if pred and expected and pred == expected:
                accepted_correct += 1
        else:
            uncertain += 1

        enriched = dict(row)
        enriched["margin"] = f"{margin:.6f}"
        enriched["decision"] = decision
        enriched["is_correct_when_accepted"] = "1" if (is_accepted and pred == expected and expected) else "0"
        annotated_rows.append(enriched)

    coverage = accepted / total
    uncertain_rate = uncertain / total
    precision_on_accepted = (accepted_correct / accepted) if accepted > 0 else 0.0

    print(f"Total samples: {total}")
    print(f"Accepted samples: {accepted}")
    print(f"Uncertain samples: {uncertain}")
    print(f"Coverage: {coverage:.4f}")
    print(f"Precision on accepted: {precision_on_accepted:.4f}")
    print(f"Uncertain rate: {uncertain_rate:.4f}")

    if args.out_csv:
        out_path = Path(args.out_csv).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        fieldnames = list(annotated_rows[0].keys())
        with open(out_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(annotated_rows)
        print(f"Annotated output: {out_path}")


if __name__ == "__main__":
    main()
