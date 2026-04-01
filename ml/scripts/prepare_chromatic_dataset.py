from __future__ import annotations

import argparse
import csv
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf
from pydub import AudioSegment


def convert_to_wav(input_audio: Path, converted_dir: Path, sr: int) -> Path:
    converted_dir.mkdir(parents=True, exist_ok=True)
    out_wav = converted_dir / f"{input_audio.stem}.wav"

    if input_audio.suffix.lower() == ".wav":
        y, in_sr = librosa.load(str(input_audio), sr=sr, mono=True)
        sf.write(str(out_wav), y, sr)
        return out_wav

    audio = AudioSegment.from_file(str(input_audio))
    audio = audio.set_channels(1).set_frame_rate(sr)
    audio.export(str(out_wav), format="wav")
    return out_wav


def onset_segments(y: np.ndarray, sr: int, min_duration: float, top_db: int) -> list[np.ndarray]:
    onsets = librosa.onset.onset_detect(y=y, sr=sr, units="samples", backtrack=True)
    boundaries = np.unique(np.concatenate(([0], onsets, [len(y)])))

    segments: list[np.ndarray] = []
    for i in range(len(boundaries) - 1):
        start = int(boundaries[i])
        end = int(boundaries[i + 1])
        seg = y[start:end]
        if len(seg) == 0:
            continue

        if len(seg) / sr < min_duration:
            continue

        trimmed, _ = librosa.effects.trim(seg, top_db=top_db)
        if len(trimmed) / sr < min_duration:
            continue

        segments.append(trimmed)

    return segments


def build_label(idx: int, string_name: str, directions: list[str], start_fret: int) -> str:
    direction_idx = idx % len(directions)
    fret = start_fret + (idx // len(directions))
    direction = directions[direction_idx]
    return f"{string_name}_fret_{fret:02d}_{direction}"


def process_file(
    input_audio: Path,
    string_name: str,
    output_dir: Path,
    converted_dir: Path,
    metadata_rows: list[dict[str, str]],
    directions: list[str],
    start_fret: int,
    max_fret: int,
    min_duration: float,
    top_db: int,
    sr: int,
) -> int:
    wav_path = convert_to_wav(input_audio, converted_dir, sr)
    y, sr = librosa.load(str(wav_path), sr=sr, mono=True)
    segments = onset_segments(y, sr=sr, min_duration=min_duration, top_db=top_db)

    output_dir.mkdir(parents=True, exist_ok=True)

    saved = 0
    max_notes = (max_fret - start_fret + 1) * len(directions)
    for idx, seg in enumerate(segments):
        if idx >= max_notes:
            break

        label = build_label(idx, string_name=string_name, directions=directions, start_fret=start_fret)
        out_name = f"{label}_{saved + 1:04d}.wav"
        out_path = output_dir / out_name
        sf.write(str(out_path), seg, sr)

        metadata_rows.append(
            {
                "segment_file": out_name,
                "label": label,
                "source_file": input_audio.name,
                "string": string_name,
                "fret": str(start_fret + (idx // len(directions))),
                "direction": directions[idx % len(directions)],
                "duration_sec": f"{len(seg)/sr:.4f}",
            }
        )
        saved += 1

    return saved


def main() -> None:
    parser = argparse.ArgumentParser(description="Prepare chromatic dombra dataset from long recordings")
    parser.add_argument("--input-dir", default="data/raw_data", help="Folder with m4a/wav source files")
    parser.add_argument("--low-file", default="Low_down_up_quiet.m4a", help="Low string recording filename")
    parser.add_argument("--up-file", default="up_string_quiet.m4a", help="Up string recording filename")
    parser.add_argument("--up-file-alt", default="Low.m4a", help="Alternative up string filename if --up-file is absent")
    parser.add_argument("--output-dir", default="data/processed_notes", help="Output note clips folder")
    parser.add_argument("--converted-dir", default="data/converted_wav", help="Temp converted wav folder")
    parser.add_argument("--metadata-csv", default="data/annotations/labels_chromatic.csv")
    parser.add_argument("--start-fret", type=int, default=0)
    parser.add_argument("--max-fret", type=int, default=12)
    parser.add_argument("--directions", default="down,up", help="Comma-separated pick directions")
    parser.add_argument("--min-duration", type=float, default=0.12)
    parser.add_argument("--top-db", type=int, default=35)
    parser.add_argument("--sr", type=int, default=22050)
    args = parser.parse_args()

    input_dir = Path(args.input_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    converted_dir = Path(args.converted_dir).resolve()
    metadata_csv = Path(args.metadata_csv).resolve()
    metadata_csv.parent.mkdir(parents=True, exist_ok=True)

    directions = [d.strip() for d in args.directions.split(",") if d.strip()]
    if not directions:
        raise SystemExit("No directions provided.")

    low_path = input_dir / args.low_file
    up_path = input_dir / args.up_file
    if not up_path.exists() and (input_dir / args.up_file_alt).exists():
        up_path = input_dir / args.up_file_alt

    missing = [str(p) for p in [low_path, up_path] if not p.exists()]
    if missing:
        raise SystemExit(f"Missing input files: {missing}")

    rows: list[dict[str, str]] = []
    low_count = process_file(
        input_audio=low_path,
        string_name="low",
        output_dir=output_dir,
        converted_dir=converted_dir,
        metadata_rows=rows,
        directions=directions,
        start_fret=args.start_fret,
        max_fret=args.max_fret,
        min_duration=args.min_duration,
        top_db=args.top_db,
        sr=args.sr,
    )
    up_count = process_file(
        input_audio=up_path,
        string_name="up",
        output_dir=output_dir,
        converted_dir=converted_dir,
        metadata_rows=rows,
        directions=directions,
        start_fret=args.start_fret,
        max_fret=args.max_fret,
        min_duration=args.min_duration,
        top_db=args.top_db,
        sr=args.sr,
    )

    with open(metadata_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["segment_file", "label", "source_file", "string", "fret", "direction", "duration_sec"],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Low string segments saved: {low_count}")
    print(f"Up string segments saved: {up_count}")
    print(f"Total saved: {len(rows)}")
    print(f"Metadata: {metadata_csv}")


if __name__ == "__main__":
    main()
