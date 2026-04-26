# Kuyshim: ML Architecture Breakdown and Recent Improvements

This document provides a detailed breakdown of the recent machine learning actions, architectural redesigns, and performance improvements implemented in the `ml/` directory for the Kuyshim project.

## 1. Model Architecture Upgrades (`model.py`)
- **Transfer Learning via ResNet18**: Upgraded the backbone to a pre-trained `ResNet18` model to leverage deep feature extraction.
- **Single-Channel Adaptation**: Modified the initial convolutional layer (`conv1`) to accept 1-channel Mel-spectrogram inputs instead of 3-channel RGB. The weights for this new layer were initialized by averaging the original 3 channels, ensuring a stable starting point.
- **Robust Classification Head**: Replaced the final fully connected layer with a new `Sequential` block. Crucially, a `Dropout(p=0.5)` layer was added before the final `Linear(num_ftrs, 38)` layer to combat overfitting and improve generalization on unseen dombra audio. 

## 2. Advanced Training Infrastructure (`train.py`)
- **Multi-Label Classification**: Transitioned the loss function to `BCEWithLogitsLoss`. Because dombra playing often involves striking two strings at once, the model must independently predict the probability for each of the 38 classes (19 frets x 2 strings).
- **Macro F1 Evaluation**: Switched the primary optimization metric from basic accuracy to **Macro F1 Score**. This is critical for evaluating multi-label tasks with imbalanced data, as it calculates metrics independently for every single fret/string and finds the unweighted mean.
- **L2 Regularization (Weight Decay)**: Switched the optimizer to `Adam` and applied explicit weight decay (`1e-4`) to enforce smaller model weights and further reduce overfitting.
- **Dynamic Learning Rate Scheduling**: Integrated `ReduceLROnPlateau`. The scheduler monitors the Validation F1 score and aggressively halves (`factor=0.5`) the learning rate if the model plateaus for 2 epochs.
- **Early Stopping Mechanism**: Implemented an early stopping threshold with a patience of 6 epochs. If the Validation F1 stops improving, training halts automatically to preserve the best weights and save compute time.

## 3. Audio Processing & On-the-Fly Augmentation (`dataset.py`)
- **DSP Pipeline Standardization**: Refactored the dataset loader to use `torchaudio`. The pipeline now consistently resamples to 22050Hz mono, limits duration to 2.0s, extracts 128-bin Mel-spectrograms, converts amplitude to DB, and applies standard zero-mean unit-variance normalization.
- **Dynamic Batch Augmentation**: To massively expand the training variance without increasing disk footprint, stochastic augmentations are now applied on-the-fly during training:
  - **Context-Aware Pitch Shifting**: Randomly shifts pitch by +/- 1 semitone. Critically, it checks if the shift pushes a note "off the fretboard" (outside the 0-18 range per string); if safe, it dynamically updates the tensor labels to match the new pitch.
  - **White Noise Injection**: Adds variable amplitude background noise (up to 1.5%) to mimic low-quality mobile phone microphones.
  - **Room Reverb Simulation**: Applies randomized delays (200-800 samples) and decay values to simulate echoing room acoustics.
- **Zero-Leakage Data Splitting**: Designed `get_data_splits()` to ensure strict train/val/test splits based on filename variation keywords (`ringing` forces validation, `human` forces testing).

## 4. Synthetic "Kuy" Generation (`generate_chords.py`)
- **Offline Interval Synthesis**: Created an automated script that cross-multiplies isolated notes from string 1 and string 2 to artificially generate hundreds of combined dombra intervals (which make up traditional *Kuy* music).
- **Realistic Micro-Delays (Strumming)**: Instead of perfectly syncing the notes, the script applies random micro-delays (10-40ms) and slight volume adjustments between the two strings. This beautifully simulates the natural physics of a human hand sweeping across the strings rather than striking them simultaneously.
