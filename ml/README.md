# ML in this repository

This folder now has two modes:

- Minimal mode (default): `ml/minimal/*`
- Legacy mode (reference only): `ml/src/*`, `ml/scripts/*`, old model artifacts

If you are restarting and want a clean path, start with `ml/minimal/README.md`.

## Minimal path (recommended)

Use these files only:

- `ml/minimal/data_utils.py`
- `ml/minimal/train.py`
- `ml/minimal/predict.py`
- `ml/minimal/README.md`

This path is intentionally simple:

- One aligned dataset loader
- One small classifier
- One single-audio prediction script

## Legacy path

Legacy components are documented in `ml/LEGACY.md` and kept for reference.

Do not delete legacy files until minimal training and prediction are stable.
