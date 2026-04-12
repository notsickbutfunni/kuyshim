#!/usr/bin/env python3
"""
Relabel dataset with coarser granularity to enable model training.
Converts granular labels (format: {string}_{fret}_{direction}) to fret-only labels (0-12).
"""

import numpy as np
import csv
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent
DATA_DIR = PROJECT_ROOT / "data"
FEATURES_DIR = DATA_DIR / "features"
ANNOTATIONS_DIR = DATA_DIR / "annotations"


def relabel_to_fret_only(labels_csv_path: str) -> np.ndarray:
    """
    Load labels from CSV and convert to fret-only format.
    Original format: 'low_fret_03_down' -> reduced to fret number: 3
    
    Args:
        labels_csv_path: Path to labels_chromatic.csv
    
    Returns:
        np.array of shape (n_samples,) with fret numbers as integers
    """
    fret_labels = []
    
    with open(labels_csv_path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            fret = int(row['fret'])
            fret_labels.append(fret)
    
    return np.array(fret_labels, dtype=np.int32)


def main():
    # Load existing feature arrays
    X_mfcc = np.load(FEATURES_DIR / "X_mfcc_summary.npy")
    X_cqt = np.load(FEATURES_DIR / "X_cqt.npy")
    X_mel = np.load(FEATURES_DIR / "X_mel.npy")
    
    print(f"Original feature shapes:")
    print(f"  X_mfcc: {X_mfcc.shape}")
    print(f"  X_cqt: {X_cqt.shape}")
    print(f"  X_mel: {X_mel.shape}")
    
    # Generate new fret-only labels
    y_frets = relabel_to_fret_only(ANNOTATIONS_DIR / "labels_chromatic.csv")
    
    print(f"\nRelabeled dataset:")
    print(f"  Total samples: {len(y_frets)}")
    print(f"  Unique classes (frets 0-12): {len(np.unique(y_frets))}")
    print(f"  Class distribution:")
    for fret in sorted(np.unique(y_frets)):
        count = np.sum(y_frets == fret)
        print(f"    Fret {fret:2d}: {count} samples")
    
    # Save relabeled dataset
    np.save(FEATURES_DIR / "y_labels_fret_only.npy", y_frets)
    print(f"\n✓ Saved relabeled dataset to: {FEATURES_DIR / 'y_labels_fret_only.npy'}")
    
    # Save summary for reference
    summary_txt = f"""Dataset Relabeling Summary
===========================

Original Granularity: string_fret_direction (52 unique classes)
New Granularity: fret_only (13 classes, frets 0-12)

Sample Distribution:
{chr(10).join(f'  Fret {fret:2d}: {np.sum(y_frets == fret)} samples' for fret in sorted(np.unique(y_frets)))}

Total trainable samples: {len(y_frets)}
Total classes: {len(np.unique(y_frets))}

Feature arrays available:
  - X_mfcc_summary.npy ({X_mfcc.shape})
  - X_cqt.npy ({X_cqt.shape})
  - X_mel.npy ({X_mel.shape})
  - y_labels_fret_only.npy ({y_frets.shape})
"""
    
    with open(FEATURES_DIR / "relabeling_summary.txt", 'w') as f:
        f.write(summary_txt)
    
    print(f"\n✓ Saved summary to: {FEATURES_DIR / 'relabeling_summary.txt'}")


if __name__ == "__main__":
    main()
