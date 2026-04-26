# ML Restart Plan (190 Recordings)

This document defines a restart plan for the ML component using a small-scale dataset (190 recordings) in a format suitable for a thesis project.

## Dataset Design (Confirmed)

The recording protocol is now fixed as:
- 2 strings;
- 19 frets per string;
- 5 variations per string-fret pair.

Total sample count:
- 2 x 19 x 5 = 190 recordings.

Recommended class definition:
- one class per string-fret pair;
- total classes = 2 x 19 = 38;
- average samples per class = 5.

Suggested variation plan (example):
- variation 1: normal clean pluck;
- variation 2: softer attack;
- variation 3: stronger attack;
- variation 4: slight timing offset;
- variation 5: realistic room/noise condition.

Naming convention (important for reproducibility):
- use deterministic names such as s1_f07_v03.wav;
- keep a metadata table with fields: file_name, string_id, fret_id, variation_id, session_id, device_id, notes.

## Recording Workflow (Two Long Files)

Your planned workflow is valid and efficient:
- play each note 10 times (5 variation types x 2 repeats);
- record one full pass for string 1 and one full pass for string 2;
- output files: `s1_all_variations.wav` and `s2_all_variations.wav`.

Expected count from this protocol:
- classes: 2 strings x 19 frets = 38 classes;
- hits per class: 10;
- total hits: 38 x 10 = 380 segmented events.

Recommended play order inside each file:
- keep fret order strictly monotonic (f0 -> f18);
- keep variation order fixed for every fret;
- insert short silence (for example 300-700 ms) between hits for cleaner onset detection.

## Segmentation Target: Onset/Offset + Pitch CSV

The immediate goal is reliable event extraction from each long WAV into one CSV table.

Minimum CSV schema:
- `source_file`
- `event_index`
- `string_id`
- `fret_id_expected`
- `variation_id_expected`
- `repeat_id_expected`
- `onset_sec`
- `offset_sec`
- `duration_sec`
- `pitch_hz`
- `pitch_midi`
- `rms_db`
- `snr_estimate_db`
- `quality_flag`
- `notes`

Where labels come from:
- `string_id` from source filename (`s1_*` or `s2_*`);
- `fret_id_expected`, `variation_id_expected`, and `repeat_id_expected` from the deterministic play order;
- onset/offset/pitch from signal processing.

## Practical Extraction Rules

Use this extraction logic to keep segmentation stable:
- detect candidate onsets from energy envelope plus spectral flux;
- define offset as the first stable low-energy region after onset;
- enforce duration bounds (for example 0.15-2.0 s);
- estimate pitch on the stable middle part of each segment (not attack-only frames);
- reject/flag events with weak energy or unstable pitch trajectory.

Quality control checks:
- event count per source file should equal 190;
- total event count should equal 380;
- pitch should increase monotonically with fret progression inside each variation block;
- flagged events should be manually reviewed and corrected in CSV.

Recommended split policy after segmentation:
- split by recording session/group, never by random segment rows alone;
- keep all repeats of the same planned hit lineage in one split to avoid leakage.

## Goal

Build a robust dombra recognition model under limited data conditions through:
- strong augmentation;
- proper audio segmentation;
- transfer learning;
- realistic task framing and evaluation metrics.

## 1) Data Augmentation as the Main Quality Lever

With only 190 source recordings, the top priority is to increase data variability.

### 1.1 Time Stretching and Pitch Shifting
- Vary tempo within a small range (for example, 0.9-1.1).
- Apply small pitch shifts (quarter-tone or semitone in both directions).
- Keep augmentation ranges constrained to preserve musical class identity.

### 1.2 Noise and Recording Conditions
- Add low-level household noise, room reverb, or weak metronome clicks.
- Vary SNR (for example, 15-30 dB) to improve robustness on real user recordings.

### 1.3 Harmonic Shaping
- Synthetically boost or attenuate selected harmonics.
- Simulate instrument and playing-style variation.

Expected effect:
- reduced overfitting;
- better robustness on real-world recordings;
- improved generalization without adding new original files.

## 2) Fragmentation of Long Recordings

If the original recordings are long, they should not be treated as only 190 training units.

### 2.1 Segmentation
- Split recordings into 1-3 second segments.
- Use overlap (for example, 30-50%).
- Filter out very quiet or empty segments.

### 2.2 Outcome
- Convert 190 long files into thousands of trainable segments (spectrogram samples).
- Preserve mapping from each segment to its source recording for correct validation.

Critical for evaluation:
- split train/val/test by source recording (group split) to avoid leakage.

## 3) Transfer Learning (Required)

Training from scratch on this dataset size is high risk.

### 3.1 Base Strategy
- Start from a pretrained audio model (for example, music or speech encoders).
- Freeze 80-90% of layers.
- Train only the classification head first, then partially unfreeze the backbone if needed.

### 3.2 Practical Training Cycle
- Stage 1: train head only.
- Stage 2: careful fine-tuning of upper backbone layers with a small learning rate.
- Use early stopping and regularization.

Expected effect:
- more stable convergence;
- better quality than training from scratch.

## 4) Realistic Task Framing

Feasibility strongly depends on the target task.

### 4.1 What Is Achievable with 190 Recordings
- Single-note/single-hit classification: realistic and achievable.
- Basic performance assessment (accuracy/timing-related indicators): achievable as a research module.

### 4.2 What Is Risky
- Full polyphonic transcription of complex kuy passages: high error risk on fast note sequences.

Recommended focus:
- first build a reliable monophonic or quasi-monophonic task;
- then increase complexity after a stable baseline is achieved.

## 5) Experiment Plan

### Step 1. Data Preparation
- Clean and verify labels.
- Segment audio and preserve source recording group IDs.
- Generate spectrograms/features.

### Step 2. Baseline
- Train a simple baseline using fixed features and a lightweight classifier.
- Record baseline metrics as the lower bound.

### Step 3. Augmentation Study
- Add augmentation types incrementally.
- Measure the contribution of each augmentation and their combinations.

### Step 4. Transfer Learning Study
- Compare frozen backbone vs partial unfreeze.
- Tune learning rate, batch size, and fine-tuning depth.

### Step 5. Final Model
- Select configuration by validation performance.
- Evaluate on a hold-out test set with group split.
- Report latency and prediction stability.

## 6) Metrics and Validation Protocol

Core metrics:
- Accuracy (top-1, optionally top-3);
- Macro F1 (important under class imbalance);
- class-level confusion matrix.

Protocol:
- group-aware split (by source recordings, not by segments);
- experiment reproducibility (seed, configs, result versioning);
- mandatory comparison against baseline.

## 7) Thesis Positioning

190 original self-recorded and self-labeled samples are a valid and strong research dataset for a thesis, provided the methodology is rigorous.

Key emphasis in writing:
- justify the limited dataset size;
- describe engineering compensations (augmentation, fragmentation, transfer learning);
- provide a transparent and reproducible evaluation protocol.

## 8) First-Iteration Success Criteria

The first iteration is considered successful if:
- the model consistently outperforms the baseline in Accuracy and Macro F1;
- quality does not collapse under noisy recordings and small tuning variations;
- results are reproducible across repeated runs.

---

This plan is the initial framework for the ML restart and can be refined after the first controlled experiments.
