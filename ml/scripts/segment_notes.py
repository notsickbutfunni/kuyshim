from __future__ import annotations

import argparse
import csv
from pathlib import Path

import librosa
import numpy as np
import soundfile as sf
from pydub import AudioSegment
from pydub.silence import split_on_silence


def sanitize_note(note: str) -> str:
    return note.strip().replace("#", "sharp").replace(" ", "_")


def onset_boundaries(y: np.ndarray, sr: int) -> np.ndarray:
    onsets = librosa.onset.onset_detect(y=y, sr=sr, units="samples", backtrack=True)
    points = np.unique(np.concatenate(([0], onsets, [len(y)])))
    return points


def segment_with_onsets(
    input_wav: Path,
    output_dir: Path,
    top_db: int,
    min_duration_sec: float,
    note_sequence: list[str] | None = None,
) -> list[dict[str, str]]:
    y, sr = librosa.load(str(input_wav), sr=None, mono=True)
    boundaries = onset_boundaries(y, sr)

    rows: list[dict[str, str]] = []
    seg_idx = 1
    label_idx = 0

    for i in range(len(boundaries) - 1):
        start = int(boundaries[i])
        end = int(boundaries[i + 1])
        segment = y[start:end]

        if len(segment) == 0:
            continue

        duration = len(segment) / sr
        if duration < min_duration_sec:
            continue

        trimmed, _ = librosa.effects.trim(segment, top_db=top_db)
        if len(trimmed) == 0:
            continue

        duration_trimmed = len(trimmed) / sr
        if duration_trimmed < min_duration_sec:
            continue

        label = "UNK"
        if note_sequence:
            label = note_sequence[label_idx % len(note_sequence)]
            label_idx += 1

        label_clean = sanitize_note(label)
        file_name = f"{label_clean}_note_{seg_idx:04d}.wav"
        out_path = output_dir / file_name
        sf.write(str(out_path), trimmed, sr)

        rows.append(
            {
                "segment_file": file_name,
                "label": label,
                "start_sec": f"{start / sr:.4f}",
                "end_sec": f"{end / sr:.4f}",
                "duration_sec": f"{duration_trimmed:.4f}",
            }
        )
        seg_idx += 1

    return rows


def segment_with_silence(
    input_wav: Path,
    output_dir: Path,
    min_silence_len: int,
    silence_thresh_db: int,
    keep_silence_ms: int,
    min_duration_sec: float,
    note_sequence: list[str] | None = None,
) -> list[dict[str, str]]:
    audio = AudioSegment.from_wav(str(input_wav))
    chunks = split_on_silence(
        audio,
        min_silence_len=min_silence_len,
        silence_thresh=silence_thresh_db,
        keep_silence=keep_silence_ms,
    )

    rows: list[dict[str, str]] = []
    seg_idx = 1
    label_idx = 0
    cursor_ms = 0

    for chunk in chunks:
        chunk_duration_sec = len(chunk) / 1000.0
        if chunk_duration_sec < min_duration_sec:
            cursor_ms += len(chunk)
            continue

        label = "UNK"
        if note_sequence:
            label = note_sequence[label_idx % len(note_sequence)]
            label_idx += 1

        label_clean = sanitize_note(label)
        file_name = f"{label_clean}_note_{seg_idx:04d}.wav"
        out_path = output_dir / file_name
        chunk.export(str(out_path), format="wav")

        start_sec = cursor_ms / 1000.0
        end_sec = start_sec + chunk_duration_sec
        rows.append(
            {
                "segment_file": file_name,
                "label": label,
                "start_sec": f"{start_sec:.4f}",
                "end_sec": f"{end_sec:.4f}",
                "duration_sec": f"{chunk_duration_sec:.4f}",
            }
        )

        cursor_ms += len(chunk)
        seg_idx += 1

    return rows


def parse_note_sequence(notes_raw: str | None) -> list[str] | None:
    if not notes_raw:
        return None
    notes = [n.strip() for n in notes_raw.split(",") if n.strip()]
    return notes or None


def main() -> None:
    parser = argparse.ArgumentParser(description="Segment long dombra recording into note clips")
    parser.add_argument("--input", required=True, help="Path to long .wav file")
    parser.add_argument("--output-dir", default="data/processed_notes", help="Output folder for note clips")
    parser.add_argument("--method", choices=["onset", "silence"], default="onset")
    parser.add_argument("--top-db", type=int, default=35, help="Trim level for librosa.effects.trim")
    parser.add_argument("--min-duration", type=float, default=0.15, help="Min note duration in seconds")
    parser.add_argument("--min-silence-len", type=int, default=180, help="Silence split min length in ms")
    parser.add_argument("--silence-thresh", type=int, default=-40, help="Silence threshold in dBFS")
    parser.add_argument("--keep-silence", type=int, default=80, help="Keep silence around chunks in ms")
    parser.add_argument(
        "--note-sequence",
        default=None,
        help="Optional comma-separated notes to auto-label in order, e.g. C,C#,D,D#,E,F,F#,G,G#,A,A#,B",
    )
    parser.add_argument("--metadata-csv", default="data/processed_notes/segments_metadata.csv")
    args = parser.parse_args()

    input_wav = Path(args.input).resolve()
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    metadata_csv = Path(args.metadata_csv).resolve()
    metadata_csv.parent.mkdir(parents=True, exist_ok=True)

    note_sequence = parse_note_sequence(args.note_sequence)

    if args.method == "onset":
        rows = segment_with_onsets(
            input_wav=input_wav,
            output_dir=output_dir,
            top_db=args.top_db,
            min_duration_sec=args.min_duration,
            note_sequence=note_sequence,
        )
    else:
        rows = segment_with_silence(
            input_wav=input_wav,
            output_dir=output_dir,
            min_silence_len=args.min_silence_len,
            silence_thresh_db=args.silence_thresh,
            keep_silence_ms=args.keep_silence,
            min_duration_sec=args.min_duration,
            note_sequence=note_sequence,
        )

    with open(metadata_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["segment_file", "label", "start_sec", "end_sec", "duration_sec"],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Saved {len(rows)} note clips to {output_dir}")
    print(f"Metadata: {metadata_csv}")


if __name__ == "__main__":
    main()
