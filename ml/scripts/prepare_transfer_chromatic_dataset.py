from __future__ import annotations

import argparse
import csv
import re
from collections import defaultdict
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf


INPUT_PATTERN = re.compile(r"^(S[12])_(.+)\.[A-Za-z0-9]+$")


def detect_segments(
    y: np.ndarray,
    sr: int,
    min_duration: float,
    max_duration: float,
    top_db: int,
    expected_notes: int,
) -> list[np.ndarray]:
    onsets = librosa.onset.onset_detect(y=y, sr=sr, units="samples", backtrack=True)
    boundaries = np.unique(np.concatenate(([0], onsets, [len(y)])))

    candidates: list[dict[str, object]] = []
    for i in range(len(boundaries) - 1):
        start = int(boundaries[i])
        end = int(boundaries[i + 1])
        seg = y[start:end]
        if len(seg) == 0:
            continue

        duration = len(seg) / sr
        if duration < min_duration:
            continue

        trimmed, _ = librosa.effects.trim(seg, top_db=top_db)
        if len(trimmed) == 0:
            continue

        trimmed_duration = len(trimmed) / sr
        if trimmed_duration < min_duration:
            continue

        if trimmed_duration > max_duration:
            trimmed = trimmed[: int(max_duration * sr)]

        rms = float(np.sqrt(np.mean(trimmed**2)))
        peak = float(np.max(np.abs(trimmed)))
        candidates.append({"start": start, "seg": trimmed, "rms": rms, "peak": peak})

    if not candidates:
        return []

    rms_arr = np.array([float(c["rms"]) for c in candidates], dtype=np.float32)
    peak_arr = np.array([float(c["peak"]) for c in candidates], dtype=np.float32)

    rms_floor = max(0.003, float(np.percentile(rms_arr, 20) * 0.6))
    peak_floor = max(0.02, float(np.percentile(peak_arr, 20) * 0.6))

    filtered = [
        c
        for c in candidates
        if float(c["rms"]) >= rms_floor and float(c["peak"]) >= peak_floor
    ]

    if not filtered:
        filtered = candidates

    if len(filtered) > expected_notes:
        filtered = sorted(filtered, key=lambda c: float(c["rms"]) * float(c["peak"]), reverse=True)[:expected_notes]

    filtered = sorted(filtered, key=lambda c: int(c["start"]))

    segments: list[np.ndarray] = [c["seg"] for c in filtered]
    return segments


def parse_input_name(path: Path) -> tuple[str, str]:
    m = INPUT_PATTERN.match(path.name)
    if not m:
        raise ValueError(
            f"Invalid input name: {path.name}. Expected format S1_variation.ext or S2_variation.ext"
        )
    string_id = m.group(1).lower()
    variation = m.group(2).lower()
    return string_id, variation


def build_class_names(max_fret: int) -> list[str]:
    class_names: list[str] = []
    for string_id in ("s1", "s2"):
        for fret in range(max_fret + 1):
            class_names.append(f"{string_id}_f{fret}")
    return class_names


def estimate_onset_flag(seg: np.ndarray, sr: int) -> float:
    onset_env = librosa.onset.onset_strength(y=seg, sr=sr)
    if onset_env.size == 0:
        return 0.0

    max_strength = float(np.max(onset_env))
    if max_strength <= 1e-8:
        return 0.0

    return 1.0 if max_strength >= 0.15 else 0.0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Prepare chromatic per-fret dataset from 10 long recordings (S1/S2 + 5 variations)."
    )
    parser.add_argument("--inputs", nargs="+", required=True, help="Paths to S1_*.m4a and S2_*.m4a files")
    parser.add_argument("--output-dir", default="data/processed_notes_transfer")
    parser.add_argument("--metadata-csv", default="data/annotations/labels_transfer_chromatic.csv")
    parser.add_argument("--max-fret", type=int, default=19, help="Last fret number. 19 means labels f0..f19")
    parser.add_argument(
        "--targets-dir",
        default="data/annotations",
        help="Directory to save y_onsets/y_frames targets and class map",
    )
    parser.add_argument(
        "--skip-target-export",
        action="store_true",
        help="Only save clips/metadata without exporting multitask targets.",
    )
    parser.add_argument("--sr", type=int, default=22050)
    parser.add_argument("--min-duration", type=float, default=0.12)
    parser.add_argument("--max-duration", type=float, default=1.2)
    parser.add_argument("--top-db", type=int, default=35)
    args = parser.parse_args()

    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    metadata_csv = Path(args.metadata_csv).resolve()
    metadata_csv.parent.mkdir(parents=True, exist_ok=True)
    targets_dir = Path(args.targets_dir).resolve()
    targets_dir.mkdir(parents=True, exist_ok=True)

    expected_notes = args.max_fret + 1
    rows: list[dict[str, str]] = []
    per_label_counter: dict[str, int] = defaultdict(int)

    for raw_input in args.inputs:
        input_path = Path(raw_input).resolve()
        if not input_path.exists():
            raise SystemExit(f"Input not found: {input_path}")

        string_id, variation = parse_input_name(input_path)

        y, sr = librosa.load(str(input_path), sr=args.sr, mono=True)
        if len(y) == 0:
            print(f"Skipping empty file: {input_path}")
            continue

        segments = detect_segments(
            y,
            sr=sr,
            min_duration=args.min_duration,
            max_duration=args.max_duration,
            top_db=args.top_db,
            expected_notes=expected_notes,
        )
        if len(segments) < expected_notes:
            print(
                f"Warning: {input_path.name} has {len(segments)} detected notes, expected {expected_notes}. "
                "Will use all detected notes in order."
            )

        segments = segments[:expected_notes]

        for fret, seg in enumerate(segments):
            label = f"{string_id}_f{fret}"
            per_label_counter[label] += 1
            take_idx = per_label_counter[label]

            out_name = f"{label}_{variation}_take{take_idx:02d}.wav"
            out_path = output_dir / out_name
            sf.write(str(out_path), seg, sr)

            rows.append(
                {
                    "segment_file": out_name,
                    "label": label,
                    "source_file": input_path.name,
                    "string": string_id,
                    "fret": str(fret),
                    "variation": variation,
                    "take": str(take_idx),
                    "duration_sec": f"{len(seg) / sr:.4f}",
                    "onset_flag": f"{estimate_onset_flag(seg, sr):.1f}",
                }
            )

        print(f"Processed {input_path.name}: {len(segments)} notes")

    with open(metadata_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "segment_file",
                "label",
                "source_file",
                "string",
                "fret",
                "variation",
                "take",
                "duration_sec",
                "onset_flag",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    if not args.skip_target_export:
        class_names = build_class_names(args.max_fret)
        class_to_idx = {name: idx for idx, name in enumerate(class_names)}

        y_frames = np.zeros((len(rows), len(class_names)), dtype=np.float32)
        y_onsets = np.zeros((len(rows), len(class_names)), dtype=np.float32)
        segment_order: list[str] = []
        group_ids: list[str] = []

        for i, row in enumerate(rows):
            label = str(row["label"])
            onset_flag = float(row.get("onset_flag") or 0.0)
            idx = class_to_idx.get(label)
            if idx is None:
                continue
            y_frames[i, idx] = 1.0
            y_onsets[i, idx] = onset_flag
            segment_order.append(str(row["segment_file"]))
            group_ids.append(f"{row['string']}_{row['variation']}_take{int(row['take']):02d}")

        np.save(targets_dir / "y_frames_transfer.npy", y_frames)
        np.save(targets_dir / "y_onsets_transfer.npy", y_onsets)
        np.save(targets_dir / "classes_transfer.npy", np.array(class_names, dtype=object))
        np.save(targets_dir / "segment_order_transfer.npy", np.array(segment_order, dtype=object))
        np.save(targets_dir / "group_ids_transfer.npy", np.array(group_ids, dtype=object))

    print(f"Saved clips: {len(rows)}")
    print(f"Output dir: {output_dir}")
    print(f"Metadata: {metadata_csv}")
    if not args.skip_target_export:
        print(f"Targets: {targets_dir / 'y_onsets_transfer.npy'}")
        print(f"Targets: {targets_dir / 'y_frames_transfer.npy'}")
        print(f"Classes: {targets_dir / 'classes_transfer.npy'}")
        print(f"Segment order: {targets_dir / 'segment_order_transfer.npy'}")
        print(f"Group IDs: {targets_dir / 'group_ids_transfer.npy'}")


if __name__ == "__main__":
    main()
