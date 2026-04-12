from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from pathlib import Path

import librosa
import numpy as np


def estimate_median_f0_hz(audio: np.ndarray, sr: int, fmin_hz: float, fmax_hz: float) -> float | None:
    """Estimate robust median F0 from short frames via autocorrelation peak search."""
    min_lag = max(1, int(sr / fmax_hz))
    max_lag = max(min_lag + 1, int(sr / fmin_hz))

    frame_size = 2048
    hop = 512
    window = np.hanning(frame_size).astype(np.float32)

    if audio.size < frame_size:
        pad = np.zeros(frame_size - audio.size, dtype=np.float32)
        audio = np.concatenate([audio.astype(np.float32), pad], axis=0)
    else:
        audio = audio.astype(np.float32)

    f0_values: list[float] = []
    for start in range(0, max(1, audio.size - frame_size + 1), hop):
        frame = audio[start : start + frame_size]
        if frame.size < frame_size:
            break

        frame = frame - np.mean(frame)
        energy = float(np.sum(frame * frame))
        if energy <= 1e-8:
            continue

        frame = frame * window
        corr = np.correlate(frame, frame, mode="full")
        corr = corr[frame_size - 1 :]

        if max_lag >= corr.size:
            continue

        search = corr[min_lag:max_lag]
        if search.size == 0:
            continue

        peak_rel = int(np.argmax(search))
        peak_lag = min_lag + peak_rel
        peak_val = float(search[peak_rel])
        ref = float(corr[0]) if corr[0] > 1e-12 else 1e-12
        periodicity = peak_val / ref

        if periodicity < 0.25:
            continue

        f0_values.append(float(sr / peak_lag))

    if not f0_values:
        return None
    return float(np.median(np.array(f0_values, dtype=np.float32)))


def hz_to_midi(hz: float) -> float:
    return float(69.0 + 12.0 * np.log2(hz / 440.0))


def cents_diff(a_hz: float, b_hz: float) -> float:
    return float(1200.0 * np.log2(a_hz / b_hz))


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Audit transfer chromatic labels by checking pitch consistency. "
            "Flags likely mislabeled rows based on monotonic violations and fret outliers."
        )
    )
    parser.add_argument("--metadata-csv", default="data/annotations/labels_transfer_chromatic.csv")
    parser.add_argument("--audio-dir", default="data/processed_notes_transfer")
    parser.add_argument("--sr", type=int, default=22050)
    parser.add_argument("--fmin-hz", type=float, default=50.0)
    parser.add_argument("--fmax-hz", type=float, default=2000.0)
    parser.add_argument("--out-csv", default="data/annotations/labels_transfer_audit_flags.csv")
    parser.add_argument(
        "--outlier-threshold-cents",
        type=float,
        default=80.0,
        help="Flag samples farther than this from class median pitch.",
    )
    args = parser.parse_args()

    metadata_csv = Path(args.metadata_csv).resolve()
    audio_dir = Path(args.audio_dir).resolve()
    out_csv = Path(args.out_csv).resolve()

    if not metadata_csv.exists():
        raise SystemExit(f"Metadata CSV not found: {metadata_csv}")

    rows: list[dict[str, str]] = []
    with open(metadata_csv, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)

    if not rows:
        raise SystemExit("No rows found in metadata CSV.")

    # Estimate pitch for each segment.
    enriched: list[dict[str, object]] = []
    missing_audio = 0
    for row in rows:
        segment_file = (row.get("segment_file") or "").strip()
        path = audio_dir / segment_file
        if not path.exists():
            missing_audio += 1
            enriched.append({**row, "f0_hz": None, "midi": None})
            continue

        y, sr = librosa.load(str(path), sr=args.sr, mono=True)
        if y.size == 0:
            enriched.append({**row, "f0_hz": None, "midi": None})
            continue

        f0 = estimate_median_f0_hz(y, sr, args.fmin_hz, args.fmax_hz)
        midi = hz_to_midi(f0) if f0 is not None else None
        enriched.append({**row, "f0_hz": f0, "midi": midi})

    # Build class medians: (string, fret) -> median f0.
    class_pitch: dict[tuple[str, int], list[float]] = defaultdict(list)
    for r in enriched:
        f0 = r.get("f0_hz")
        if f0 is None:
            continue
        try:
            key = ((r.get("string") or "").strip(), int(r.get("fret") or -1))
        except ValueError:
            continue
        class_pitch[key].append(float(f0))

    class_medians: dict[tuple[str, int], float] = {
        k: float(np.median(v)) for k, v in class_pitch.items() if v
    }

    # Monotonic check by source_file (each long recording).
    by_source: dict[str, list[dict[str, object]]] = defaultdict(list)
    for r in enriched:
        source_file = str(r.get("source_file") or "")
        by_source[source_file].append(r)

    flags: list[dict[str, object]] = []

    for source_file, samples in by_source.items():
        def _safe_fret(x: dict[str, object]) -> int:
            try:
                return int(x.get("fret") or -1)
            except ValueError:
                return -1

        ordered = sorted(samples, key=_safe_fret)

        prev_f0: float | None = None
        prev_seg: str | None = None
        for s in ordered:
            f0 = s.get("f0_hz")
            seg = str(s.get("segment_file") or "")
            if f0 is None:
                continue
            f0 = float(f0)

            if prev_f0 is not None and f0 <= prev_f0:
                flags.append(
                    {
                        "segment_file": seg,
                        "source_file": source_file,
                        "string": s.get("string"),
                        "fret": s.get("fret"),
                        "issue": "non_monotonic_pitch",
                        "detail": f"pitch {f0:.2f} Hz <= previous {prev_f0:.2f} Hz ({prev_seg})",
                    }
                )

            prev_f0 = f0
            prev_seg = seg

    # Outlier check against class medians.
    for s in enriched:
        f0 = s.get("f0_hz")
        if f0 is None:
            continue

        seg = str(s.get("segment_file") or "")
        string_id = str(s.get("string") or "").strip()
        try:
            fret = int(s.get("fret") or -1)
        except ValueError:
            continue

        key = (string_id, fret)
        center = class_medians.get(key)
        if center is None:
            continue

        delta_cents = abs(cents_diff(float(f0), center))
        if delta_cents >= args.outlier_threshold_cents:
            flags.append(
                {
                    "segment_file": seg,
                    "source_file": s.get("source_file"),
                    "string": string_id,
                    "fret": fret,
                    "issue": "class_pitch_outlier",
                    "suggested_fret": "",
                    "detail": f"{delta_cents:.1f} cents from class median ({center:.2f} Hz)",
                }
            )

    # Add suggested fret for all flags where pitch is available.
    for fl in flags:
        seg = str(fl.get("segment_file") or "")
        sample = next((x for x in enriched if str(x.get("segment_file") or "") == seg), None)
        if sample is None or sample.get("f0_hz") is None:
            fl["suggested_fret"] = ""
            continue

        string_id = str(sample.get("string") or "").strip()
        f0 = float(sample.get("f0_hz"))

        candidates = [(fret, hz) for (s_id, fret), hz in class_medians.items() if s_id == string_id]
        if not candidates:
            fl["suggested_fret"] = ""
            continue

        best_fret = min(candidates, key=lambda t: abs(cents_diff(f0, float(t[1]))))[0]
        fl["suggested_fret"] = str(best_fret)

    # Save report.
    out_csv.parent.mkdir(parents=True, exist_ok=True)
    with open(out_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["segment_file", "source_file", "string", "fret", "issue", "suggested_fret", "detail"],
        )
        writer.writeheader()
        for row in flags:
            writer.writerow(row)

    print(f"Rows in metadata: {len(rows)}")
    print(f"Missing audio files: {missing_audio}")
    print(f"Class medians computed: {len(class_medians)}")
    print(f"Flags written: {len(flags)}")
    print(f"Report: {out_csv}")


if __name__ == "__main__":
    main()
