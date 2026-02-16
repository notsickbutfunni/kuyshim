# Machine Learning - Audio Analysis & Performance Evaluation

Audio processing and ML models for dombra chord/note detection and user performance evaluation.

## 📚 What Goes Here

- Audio preprocessing pipeline
- Dombra note/chord recognition models
- User performance evaluation (pitch accuracy, timing, rhythm)
- Pitch detection algorithms
- Audio feature extraction
- Model training scripts
- Inference services (REST API or gRPC)
- Test audio samples

## 🛠️ Tech Stack

- **Language**: Python 3.8+
- **Audio Processing**: librosa, scipy, soundfile
- **Deep Learning**: PyTorch
- **Signal Processing**: numpy, scipy, essentia
- **Model Serving**: FastAPI for inference API
- **Evaluation Metrics**: custom scoring algorithms

## 📁 Project Structure 

```
ml/
├── data/
│   ├── raw_samples/          # Original dombra recordings
│   ├── processed/            # Preprocessed audio
│   └── annotations/          # Labels CSV and notes
├── models/
│   └── trained_models/       # Saved models (.pth)
├── notebooks/                # Exploration notebooks (optional)
├── src/
│   ├── audio_processor.py    # Preprocessing helpers
│   ├── chroma_extractor.py   # CQT chroma features
│   ├── dataset_builder.py    # Build .npy dataset from labels CSV
│   ├── dataset_schema.py     # Label schema + basic chord list
│   ├── feature_extractor.py  # Lightweight spectral features
│   ├── model.py              # CNN model definition (PyTorch)
│   ├── predict.py            # Single-file prediction
│   └── train_cnn.py          # Training loop
├── requirements.txt
└── README.md
```

## 🎵 Key ML Tasks

### 1. **Pitch Detection**
- Extract fundamental frequency from user audio
- Compare with reference note

### 2. **Chord Recognition**
- Identify which dombra chords are being played
- Match against chord database

### 3. **Performance Scoring**
- **Pitch Accuracy**: How close to target note
- **Timing Accuracy**: How close to expected rhythm
- **Rhythm**: Consistency and timing of strums

### 4. **Audio Features**
- Spectral features (MFCC, Chromagram)
- Zero-crossing rate
- Energy envelope
- Onset detection

## 📊 Model Considerations

- **Training Data**: Need recordings of proper dombra playing
- **Real-time Inference**: Must work with streaming audio
- **Latency**: Keep under 100-200ms for user feedback
- **Robustness**: Handle background noise, poor microphone quality

## 🚀 Getting Started

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
