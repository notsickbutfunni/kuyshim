from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

import librosa
import librosa.display
import matplotlib.pyplot as plt
import numpy as np

from src.augmentation import AudioAugmentor, AugmentationConfig


def load_labels_from_metadata(metadata_csv: Path) -> dict[str, str]:
    if not metadata_csv.exists():
        return {}

    labels: dict[str, str] = {}
    with open(metadata_csv, "r", newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = (row.get("segment_file") or "").strip()
            label = (row.get("label") or "UNK").strip() or "UNK"
            if name:
                labels[name] = label
    return labels


def infer_label(file_name: str, labels_map: dict[str, str]) -> str:
    if file_name in labels_map:
        return labels_map[file_name]

    lower_name = file_name.lower()
    transfer_match = re.match(r"^(s[12]_f\d+)", lower_name)
    if transfer_match:
        return transfer_match.group(1)

    prefix = file_name.split("_note_")[0]
    return prefix if prefix else "UNK"


def pad_or_trim(mat: np.ndarray, target_frames: int) -> np.ndarray:
    if mat.shape[1] == target_frames:
        return mat
    if mat.shape[1] > target_frames:
        return mat[:, :target_frames]
    pad = np.zeros((mat.shape[0], target_frames - mat.shape[1]), dtype=mat.dtype)
    return np.concatenate([mat, pad], axis=1)


def save_feature_plot(feature: np.ndarray, title: str, out_path: Path, y_axis: str | None = None) -> None:
    plt.figure(figsize=(12, 4), dpi=300)
    librosa.display.specshow(feature, x_axis="time", y_axis=y_axis)
    plt.title(title)
    plt.colorbar(format="%+2.0f dB")
    plt.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    plt.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract MFCC, CQT, and Mel-spectrogram features")
    parser.add_argument("--input-dir", default="data/processed_notes", help="Segmented notes folder")
    parser.add_argument("--metadata-csv", default="data/processed_notes/segments_metadata.csv")
    parser.add_argument("--out-dir", default="data/features")
    parser.add_argument("--n-mfcc", type=int, default=20)
    parser.add_argument("--target-frames", type=int, default=128)
    parser.add_argument("--n-mels", type=int, default=128)
    parser.add_argument("--save-plots", action="store_true")
    parser.add_argument("--plot-limit", type=int, default=100, help="Max number of segments to plot")
    parser.add_argument("--augment", action="store_true", help="Enable audio-domain augmentation")
    parser.add_argument("--aug-copies", type=int, default=0, help="Number of augmented copies per file")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--stretch-min", type=float, default=0.95)
    parser.add_argument("--stretch-max", type=float, default=1.05)
    parser.add_argument("--max-pitch-cents", type=float, default=20.0)
    parser.add_argument("--noise-snr-min", type=float, default=18.0)
    parser.add_argument("--noise-snr-max", type=float, default=28.0)
    parser.add_argument("--noise-dir", default=None, help="Optional folder with background noise .wav files")
    args = parser.parse_args()

    input_dir = Path(args.input_dir).resolve()
    metadata_csv = Path(args.metadata_csv).resolve()
    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    labels_map = load_labels_from_metadata(metadata_csv)
    wav_files = sorted(input_dir.glob("*.wav"))
    if not wav_files:
        raise SystemExit(f"No .wav files found in {input_dir}")

    augmentor: AudioAugmentor | None = None
    if args.augment and args.aug_copies > 0:
        augmentor = AudioAugmentor(
            AugmentationConfig(
                stretch_min=args.stretch_min,
                stretch_max=args.stretch_max,
                max_pitch_cents=args.max_pitch_cents,
                noise_snr_min_db=args.noise_snr_min,
                noise_snr_max_db=args.noise_snr_max,
                noise_dir=args.noise_dir,
                seed=args.seed,
            )
        )

    mfcc_summary_list: list[np.ndarray] = []
    cqt_list: list[np.ndarray] = []
    mel_list: list[np.ndarray] = []
    labels: list[str] = []
    names: list[str] = []
    augmented_samples = 0

    plots_saved = 0
    for wav_path in wav_files:
        y, sr = librosa.load(str(wav_path), sr=22050, mono=True)
        if len(y) == 0:
            continue

        samples: list[tuple[np.ndarray, str]] = [(y, wav_path.name)]
        if augmentor is not None:
            for aug_idx in range(args.aug_copies):
                y_aug, _meta = augmentor.augment(y, sr)
                samples.append((y_aug, f"{wav_path.stem}__aug{aug_idx+1}.wav"))
                augmented_samples += 1

        label = infer_label(wav_path.name, labels_map)

        for sample_audio, sample_name in samples:
            mfcc = librosa.feature.mfcc(y=sample_audio, sr=sr, n_mfcc=args.n_mfcc)
            cqt = np.abs(librosa.cqt(sample_audio, sr=sr, n_bins=84, bins_per_octave=12))
            mel = librosa.feature.melspectrogram(y=sample_audio, sr=sr, n_mels=args.n_mels)

            cqt = pad_or_trim(cqt, args.target_frames)
            mel = pad_or_trim(mel, args.target_frames)

            mfcc_mean = np.mean(mfcc, axis=1)
            mfcc_std = np.std(mfcc, axis=1)
            mfcc_summary = np.concatenate([mfcc_mean, mfcc_std], axis=0)

            mfcc_summary_list.append(mfcc_summary.astype(np.float32))
            cqt_list.append(cqt.astype(np.float32))
            mel_list.append(mel.astype(np.float32))
            labels.append(label)
            names.append(sample_name)

            if args.save_plots and plots_saved < args.plot_limit:
                mel_db = librosa.power_to_db(mel, ref=np.max)
                cqt_db = librosa.amplitude_to_db(cqt, ref=np.max)

                sample_stem = Path(sample_name).stem
                save_feature_plot(
                    feature=mfcc,
                    title=f"MFCC - {sample_name}",
                    out_path=out_dir / "plots" / "mfcc" / f"{sample_stem}_mfcc.png",
                    y_axis=None,
                )
                save_feature_plot(
                    feature=cqt_db,
                    title=f"CQT - {sample_name}",
                    out_path=out_dir / "plots" / "cqt" / f"{sample_stem}_cqt.png",
                    y_axis="cqt_note",
                )
                save_feature_plot(
                    feature=mel_db,
                    title=f"Mel Spectrogram - {sample_name}",
                    out_path=out_dir / "plots" / "mel" / f"{sample_stem}_mel.png",
                    y_axis="mel",
                )
                plots_saved += 1

    X_mfcc = np.stack(mfcc_summary_list, axis=0)
    X_cqt = np.stack(cqt_list, axis=0)
    X_mel = np.stack(mel_list, axis=0)
    y_labels = np.array(labels)
    file_names = np.array(names)

    np.save(out_dir / "X_mfcc_summary.npy", X_mfcc)
    np.save(out_dir / "X_cqt.npy", X_cqt)
    np.save(out_dir / "X_mel.npy", X_mel)
    np.save(out_dir / "y_labels.npy", y_labels)
    np.save(out_dir / "file_names.npy", file_names)

    csv_path = out_dir / "dataset_mfcc_summary.csv"
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        header = ["file", "label"] + [f"mfcc_{i+1}" for i in range(X_mfcc.shape[1])]
        writer = csv.writer(f)
        writer.writerow(header)
        for i in range(len(file_names)):
            writer.writerow([file_names[i], y_labels[i], *X_mfcc[i].tolist()])

    print(f"Processed segments: {len(file_names)}")
    if augmentor is not None:
        print(f"Augmented samples created: {augmented_samples}")
    print(f"Saved arrays in: {out_dir}")
    print(f"Saved MFCC table: {csv_path}")
    if args.save_plots:
        print(f"Saved plots: {plots_saved}")


if __name__ == "__main__":
    main()
