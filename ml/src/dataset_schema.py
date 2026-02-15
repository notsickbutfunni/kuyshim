from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, List

import csv


BASIC_CHORDS = [
    "A",
    "Am",
    "C",
    "D",
    "Dm",
    "E",
    "Em",
    "G",
]


@dataclass(frozen=True)
class ClipLabel:
    path: str
    chord: str
    tempo_bpm: int | None = None
    take: int | None = None


def write_template_csv(path: str, chord_list: Iterable[str] = BASIC_CHORDS) -> None:
    with open(path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["path", "chord", "tempo_bpm", "take"])
        for chord in chord_list:
            writer.writerow(["", chord, "", ""])


def load_labels_csv(path: str) -> List[ClipLabel]:
    labels: List[ClipLabel] = []
    with open(path, "r", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            path_value = (row.get("path") or "").strip()
            chord_value = (row.get("chord") or "").strip()
            tempo_value = (row.get("tempo_bpm") or "").strip()
            take_value = (row.get("take") or "").strip()

            tempo = int(tempo_value) if tempo_value else None
            take = int(take_value) if take_value else None

            if not path_value or not chord_value:
                continue

            labels.append(ClipLabel(path=path_value, chord=chord_value, tempo_bpm=tempo, take=take))

    return labels
