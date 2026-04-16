# Minimal ML contour

This folder is the clean restart path for ML.

Scope:
- Train one simple classifier from your recorded dataset
- Save model + classes + metrics
- Predict from one audio file

No multi-stage CV, no release packaging, no complex heads.

## Dataset expected

Defaults are already set for this repository:
- `ml/data/features_transfer/X_mel_transfer_aligned.npy`
- `ml/data/features_transfer/y_labels.npy`
- `ml/data/features_transfer/file_names.npy`
- `ml/data/annotations/segment_order_transfer.npy`
- `ml/data/annotations/classes_transfer.npy`

`train.py` auto-aligns labels to segment order by filename.

## Run in 3 commands

From repository root:

```powershell
c:/Users/kaira/kuyshim/.venv/Scripts/python.exe ml/minimal/train.py --epochs 8 --out-dir ml/models/minimal_v1
c:/Users/kaira/kuyshim/.venv/Scripts/python.exe ml/minimal/predict.py --audio ml/data/raw_data/sample.wav --model ml/models/minimal_v1/model.pth --classes ml/models/minimal_v1/classes.npy
uvicorn ml.api:app --host 0.0.0.0 --port 8001
```

Notes:
- Replace `ml/data/raw_data/sample.wav` with any real audio file path.
- The third command starts existing API service; keep it only if you need backend integration.

## Quick evaluation (top-k + confusion matrix)

```powershell
c:/Users/kaira/kuyshim/.venv/Scripts/python.exe ml/minimal/evaluate.py --model ml/models/minimal_smoke/model.pth --classes ml/models/minimal_smoke/classes.npy --out-dir ml/models/minimal_smoke/eval
```

This writes:
- `metrics.json`
- `confusion_matrix.csv`
- `topk_errors.csv`

## CRNN + CQT pilot

This is a sequence-modeling experiment for dombra dynamics.

Train:

```powershell
c:/Users/kaira/kuyshim/.venv/Scripts/python.exe ml/minimal/train_crnn.py --epochs 20 --out-dir ml/models/crnn_v1
```

Predict:

```powershell
c:/Users/kaira/kuyshim/.venv/Scripts/python.exe ml/minimal/predict_crnn.py --audio ml/data/processed_notes_transfer/s1_f0_diff_take01.wav --model ml/models/crnn_v1/model.pth --classes ml/models/crnn_v1/classes.npy --feature-config ml/models/crnn_v1/feature_config.json
```
