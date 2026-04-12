from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


CENTS_RE = re.compile(r"([0-9]+(?:\.[0-9]+)?)\s*cents")


def parse_cents(detail: str) -> float | None:
    m = CENTS_RE.search(detail)
    if not m:
        return None
    return float(m.group(1))


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Apply high-confidence auto-fixes to transfer labels using audit flags. "
            "Only class_pitch_outlier rows above threshold are applied by default."
        )
    )
    parser.add_argument("--metadata-csv", default="data/annotations/labels_transfer_chromatic.csv")
    parser.add_argument("--flags-csv", default="data/annotations/labels_transfer_audit_flags.csv")
    parser.add_argument("--out-csv", default="data/annotations/labels_transfer_chromatic_autofix.csv")
    parser.add_argument("--review-csv", default="data/annotations/labels_transfer_autofix_review.csv")
    parser.add_argument(
        "--min-cents",
        type=float,
        default=300.0,
        help="Minimum outlier distance (in cents) required to auto-apply a correction.",
    )
    args = parser.parse_args()

    metadata_csv = Path(args.metadata_csv).resolve()
    flags_csv = Path(args.flags_csv).resolve()
    out_csv = Path(args.out_csv).resolve()
    review_csv = Path(args.review_csv).resolve()

    if not metadata_csv.exists():
        raise SystemExit(f"Metadata CSV not found: {metadata_csv}")
    if not flags_csv.exists():
        raise SystemExit(f"Flags CSV not found: {flags_csv}")

    with open(metadata_csv, "r", newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    with open(flags_csv, "r", newline="", encoding="utf-8") as f:
        flags = list(csv.DictReader(f))

    # Pick the strongest high-confidence suggestion for each segment.
    # High-confidence is defined as class_pitch_outlier with cents >= min-cents.
    best_fix_by_segment: dict[str, tuple[int, float, str]] = {}
    for fl in flags:
        if (fl.get("issue") or "").strip() != "class_pitch_outlier":
            continue

        seg = (fl.get("segment_file") or "").strip()
        suggested_raw = (fl.get("suggested_fret") or "").strip()
        detail = (fl.get("detail") or "").strip()
        cents = parse_cents(detail)

        if not seg or not suggested_raw or cents is None or cents < args.min_cents:
            continue

        try:
            suggested = int(suggested_raw)
        except ValueError:
            continue

        prev = best_fix_by_segment.get(seg)
        if prev is None or cents > prev[1]:
            best_fix_by_segment[seg] = (suggested, cents, detail)

    applied = 0
    skipped_same = 0
    review_rows: list[dict[str, str]] = []

    for row in rows:
        seg = (row.get("segment_file") or "").strip()
        current_label = (row.get("label") or "").strip()
        string_id = (row.get("string") or "").strip()

        fix = best_fix_by_segment.get(seg)
        if fix is None:
            continue

        suggested_fret, cents, reason = fix

        try:
            old_fret = int((row.get("fret") or "").strip())
        except ValueError:
            continue

        if suggested_fret == old_fret:
            skipped_same += 1
            continue

        row["fret"] = str(suggested_fret)
        row["label"] = f"{string_id}_f{suggested_fret}"

        review_rows.append(
            {
                "segment_file": seg,
                "source_file": (row.get("source_file") or "").strip(),
                "string": string_id,
                "old_fret": str(old_fret),
                "new_fret": str(suggested_fret),
                "old_label": current_label,
                "new_label": row["label"],
                "evidence_cents": f"{cents:.1f}",
                "evidence": reason,
            }
        )
        applied += 1

    out_csv.parent.mkdir(parents=True, exist_ok=True)
    review_csv.parent.mkdir(parents=True, exist_ok=True)

    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        if not rows:
            raise SystemExit("Metadata CSV is empty.")
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

    with open(review_csv, "w", newline="", encoding="utf-8") as f:
        fieldnames = [
            "segment_file",
            "source_file",
            "string",
            "old_fret",
            "new_fret",
            "old_label",
            "new_label",
            "evidence_cents",
            "evidence",
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(review_rows)

    print(f"Input rows: {len(rows)}")
    print(f"Candidate segments above threshold: {len(best_fix_by_segment)}")
    print(f"Applied fixes: {applied}")
    print(f"Skipped (suggested equals current): {skipped_same}")
    print(f"Corrected metadata: {out_csv}")
    print(f"Review log: {review_csv}")


if __name__ == "__main__":
    main()
