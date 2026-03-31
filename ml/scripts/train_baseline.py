from __future__ import annotations

import argparse
from pathlib import Path

import joblib
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.svm import SVC


def build_model(model_name: str, random_state: int):
    if model_name == "rf":
        return RandomForestClassifier(
            n_estimators=300,
            max_depth=None,
            min_samples_split=2,
            random_state=random_state,
            n_jobs=-1,
        )

    return SVC(kernel="rbf", C=10.0, gamma="scale", probability=True, random_state=random_state)


def save_confusion_matrix(cm: np.ndarray, class_names: list[str], out_path: Path, title: str) -> None:
    plt.figure(figsize=(10, 8), dpi=300)
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=class_names, yticklabels=class_names)
    plt.title(title)
    plt.xlabel("Predicted")
    plt.ylabel("True")
    plt.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out_path, dpi=300, bbox_inches="tight")
    plt.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Train fast baseline classifier on MFCC features")
    parser.add_argument("--features", default="data/features/X_mfcc_summary.npy")
    parser.add_argument("--labels", default="data/features/y_labels.npy")
    parser.add_argument("--model", choices=["rf", "svm"], default="rf")
    parser.add_argument("--test-size", type=float, default=0.2)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out-dir", default="models/baseline")
    args = parser.parse_args()

    X = np.load(args.features)
    y_text = np.load(args.labels)

    if len(X) == 0:
        raise SystemExit("No features found. Run extract_features.py first.")

    encoder = LabelEncoder()
    y = encoder.fit_transform(y_text)

    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=args.test_size,
        random_state=args.seed,
        stratify=y if len(np.unique(y)) > 1 else None,
    )

    clf = build_model(args.model, args.seed)
    clf.fit(X_train, y_train)
    y_pred = clf.predict(X_test)

    report = classification_report(y_test, y_pred, target_names=encoder.classes_, digits=4, zero_division=0)
    cm = confusion_matrix(y_test, y_pred)

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    model_path = out_dir / f"{args.model}_baseline.joblib"
    encoder_path = out_dir / "label_encoder.joblib"
    report_path = out_dir / "classification_report.txt"
    cm_png = out_dir / "confusion_matrix.png"

    joblib.dump(clf, model_path)
    joblib.dump(encoder, encoder_path)

    with open(report_path, "w", encoding="utf-8") as f:
        f.write(report)

    save_confusion_matrix(cm, encoder.classes_.tolist(), cm_png, title=f"{args.model.upper()} Baseline Confusion Matrix")

    print("Training complete.")
    print(f"Model: {model_path}")
    print(f"Encoder: {encoder_path}")
    print(f"Report: {report_path}")
    print(f"Confusion matrix: {cm_png}")
    print("\nClassification Report:\n")
    print(report)


if __name__ == "__main__":
    main()
