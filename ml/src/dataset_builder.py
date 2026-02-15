from __future__ import annotations

import argparse
from typing import Dict, List, Tuple

import numpy as np

from .chroma_extractor import ChromaConfig, compute_chroma_from_file
from .dataset_schema import BASIC_CHORDS, load_labels_csv


def build_dataset(labels_csv: str, output_path: str, chord_list: List[str] | None = None) -> None:
    if chord_list is None:
        chord_list = BASIC_CHORDS

    chord_to_id: Dict[str, int] = {chord: idx for idx, chord in enumerate(chord_list)}
    labels = load_labels_csv(labels_csv)

    dataset: List[Tuple[np.ndarray, int]] = []
    config = ChromaConfig()

    for entry in labels:
        if entry.chord not in chord_to_id:
            continue
        chroma, _ = compute_chroma_from_file(entry.path, config)
        dataset.append((chroma, chord_to_id[entry.chord]))

    np.save(output_path, np.array(dataset, dtype=object))


def main() -> None:
    parser = argparse.ArgumentParser(description="Build chroma dataset from labeled audio clips.")
    parser.add_argument("--labels", required=True, help="Path to labels CSV")
    parser.add_argument("--out", required=True, help="Output .npy path")
    args = parser.parse_args()

    build_dataset(args.labels, args.out)


if __name__ == "__main__":
    main()
