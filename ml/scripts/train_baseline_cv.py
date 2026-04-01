#!/usr/bin/env python3
"""
Train baseline classifiers (RF, SVM) on small fret classification dataset.
Uses cross-validation instead of single train/test split for datasets with <= 100 samples.
"""

import argparse
from pathlib import Path

import joblib
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import cross_validate, StratifiedKFold
from sklearn.preprocessing import LabelEncoder
from sklearn.svm import SVC


def build_model(model_name: str, random_state: int):
    if model_name == "rf":
        return RandomForestClassifier(
            n_estimators=100,
            max_depth=15,
            min_samples_split=2,
            random_state=random_state,
            n_jobs=-1,
            verbose=1,
        )
    return SVC(kernel="rbf", C=1.0, gamma="scale", probability=True, random_state=random_state)


def main() -> None:
    parser = argparse.ArgumentParser(description="Train baseline classifier with cross-validation")
    parser.add_argument("--features", default="data/features/X_mfcc_summary.npy")
    parser.add_argument("--labels", default="data/features/y_labels_fret_only.npy")
    parser.add_argument("--model", choices=["rf", "svm"], default="rf")
    parser.add_argument("--folds", type=int, default=5)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out-dir", default="models/baseline_cv")
    args = parser.parse_args()

    # Load features and labels
    X = np.load(args.features)
    y = np.load(args.labels)

    print(f"\n{'='*60}")
    print(f"Training Baseline {args.model.upper()} Classifier (Cross-Validation)")
    print(f"{'='*60}")
    print(f"Dataset shape: X={X.shape}, y={y.shape}")
    print(f"Unique classes: {len(np.unique(y))}")
    print(f"Cross-validation folds: {args.folds}\n")

    # Encode labels
    le = LabelEncoder()
    y_encoded = le.fit_transform(y)
    class_names = [f"Fret {int(c)}" for c in le.classes_]

    # Build and train model with K-Fold cross-validation
    model = build_model(args.model, args.seed)
    cv = StratifiedKFold(n_splits=args.folds, shuffle=True, random_state=args.seed)

    # Run cross-validation
    print(f"Running {args.folds}-fold cross-validation...\n")
    cv_results = cross_validate(
        model,
        X,
        y_encoded,
        cv=cv,
        scoring=["accuracy", "f1_weighted", "precision_weighted", "recall_weighted"],
        return_train_score=True,
        n_jobs=-1,
    )

    # Print results
    print(f"\nCross-Validation Results ({args.folds} folds):")
    print(f"  Train Accuracy:  {cv_results['train_accuracy'].mean():.4f} ± {cv_results['train_accuracy'].std():.4f}")
    print(f"  Test Accuracy:   {cv_results['test_accuracy'].mean():.4f} ± {cv_results['test_accuracy'].std():.4f}")
    print(f"  Train F1 (weighted): {cv_results['train_f1_weighted'].mean():.4f} ± {cv_results['train_f1_weighted'].std():.4f}")
    print(f"  Test F1 (weighted):  {cv_results['test_f1_weighted'].mean():.4f} ± {cv_results['test_f1_weighted'].std():.4f}")

    # Train final model on full dataset for artifacts
    print(f"\nTraining final model on full dataset for confusion matrix...\n")
    model.fit(X, y_encoded)

    # Get predictions on full dataset
    y_pred = model.predict(X)

    # Compute confusion matrix
    cm = confusion_matrix(y_encoded, y_pred)

    # Save model
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    model_path = out_dir / f"{args.model}_model.joblib"
    joblib.dump(model, model_path)
    print(f"✓ Model saved: {model_path}")

    # Save confusion matrix
    cm_path = out_dir / f"confusion_matrix_{args.model}.png"
    plt.figure(figsize=(12, 10), dpi=300)
    sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=class_names, yticklabels=class_names, cbar_kws={"label": "Count"})
    plt.title(f"Confusion Matrix - {args.model.upper()} ({args.folds}-Fold CV)")
    plt.xlabel("Predicted Fret")
    plt.ylabel("True Fret")
    plt.tight_layout()
    plt.savefig(cm_path, dpi=300, bbox_inches="tight")
    plt.close()
    print(f"✓ Confusion matrix saved: {cm_path}")

    # Save classification report
    report = classification_report(y_encoded, y_pred, target_names=class_names)
    report_path = out_dir / f"classification_report_{args.model}.txt"
    with open(report_path, "w") as f:
        f.write(f"Classification Report - {args.model.upper()}\n")
        f.write(f"{'='*60}\n\n")
        f.write(report)
    print(f"✓ Classification report saved: {report_path}")

    # Save CV results summary
    cv_summary_path = out_dir / f"cv_results_{args.model}.txt"
    with open(cv_summary_path, "w") as f:
        f.write(f"Cross-Validation Results Summary ({args.folds} folds)\n")
        f.write(f"{'='*60}\n\n")
        f.write(f"Test Accuracy:   {cv_results['test_accuracy'].mean():.4f} ± {cv_results['test_accuracy'].std():.4f}\n")
        f.write(f"Test F1 (weighted): {cv_results['test_f1_weighted'].mean():.4f} ± {cv_results['test_f1_weighted'].std():.4f}\n")
        f.write(f"Test Precision:  {cv_results['test_precision_weighted'].mean():.4f} ± {cv_results['test_precision_weighted'].std():.4f}\n")
        f.write(f"Test Recall:     {cv_results['test_recall_weighted'].mean():.4f} ± {cv_results['test_recall_weighted'].std():.4f}\n")
    print(f"✓ CV summary saved: {cv_summary_path}")

    print(f"\n{'='*60}\n")


if __name__ == "__main__":
    main()
