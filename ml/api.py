"""
ML Inference API — FastAPI server for Dombra chord/fret prediction.

Loads the trained DombraResNet model and serves predictions via:
  GET  /health   → model status
  POST /predict  → accepts WAV file, returns predicted class + confidence

Run: uvicorn api:app --host 0.0.0.0 --port 8001 --reload
"""
import os
import io
import torch
import torchaudio
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from model import DombraResNet

# ── Config ──────────────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(SCRIPT_DIR, "models", "trained_models")
SAMPLE_RATE = 22050
N_MELS = 128
N_FFT = 1024
HOP_LENGTH = 256
MAX_LEN_SEC = 2.0
MAX_LEN_SAMPLES = int(SAMPLE_RATE * MAX_LEN_SEC)
NUM_CLASSES = 38

# Label mapping: index → human-readable class name
# 0-18: string 1 (bass) frets 0-18, 19-37: string 2 (treble) frets 0-18
LABEL_NAMES = []
for s in [1, 2]:
    for f in range(19):
        LABEL_NAMES.append(f"s{s}_f{f:02d}")

# ── App ─────────────────────────────────────────────────────────
app = FastAPI(title="Kuyshim ML API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Model loading ──────────────────────────────────────────────
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = None
model_loaded = False

def load_model():
    global model, model_loaded
    # Try finetuned first, then baseline
    for name in ["best_dombra_finetuned.pth", "best_dombra_baseline.pth"]:
        path = os.path.join(MODEL_DIR, name)
        if os.path.exists(path):
            print(f"[ML] Loading model from {path}")
            model = DombraResNet(num_classes=NUM_CLASSES, freeze_backbone=False).to(device)
            state_dict = torch.load(path, map_location=device, weights_only=True)
            # Handle old state_dict format without Dropout layer
            if "backbone.fc.weight" in state_dict:
                state_dict["backbone.fc.1.weight"] = state_dict.pop("backbone.fc.weight")
                state_dict["backbone.fc.1.bias"] = state_dict.pop("backbone.fc.bias")
            model.load_state_dict(state_dict)
            model.eval()
            model_loaded = True
            print(f"[ML] Model loaded successfully ({name}) on {device}")
            return
    print("[ML] WARNING: No trained model found in", MODEL_DIR)

load_model()

# ── Audio preprocessing ────────────────────────────────────────
mel_transform = torchaudio.transforms.MelSpectrogram(
    sample_rate=SAMPLE_RATE,
    n_fft=N_FFT,
    hop_length=HOP_LENGTH,
    n_mels=N_MELS,
)
amp_to_db = torchaudio.transforms.AmplitudeToDB()

def preprocess_audio(audio_bytes: bytes) -> torch.Tensor:
    """Convert raw WAV bytes → normalized mel-spectrogram tensor."""
    waveform, sr = torchaudio.load(io.BytesIO(audio_bytes))

    # Resample if needed
    if sr != SAMPLE_RATE:
        resampler = torchaudio.transforms.Resample(orig_freq=sr, new_freq=SAMPLE_RATE)
        waveform = resampler(waveform)

    # Mono
    if waveform.shape[0] > 1:
        waveform = torch.mean(waveform, dim=0, keepdim=True)

    # Pad or truncate to MAX_LEN_SAMPLES
    if waveform.shape[1] > MAX_LEN_SAMPLES:
        waveform = waveform[:, :MAX_LEN_SAMPLES]
    elif waveform.shape[1] < MAX_LEN_SAMPLES:
        padding = MAX_LEN_SAMPLES - waveform.shape[1]
        waveform = torch.nn.functional.pad(waveform, (0, padding))

    # Mel spectrogram + dB + normalize
    mel = mel_transform(waveform)
    mel_db = amp_to_db(mel)
    mel_db = (mel_db - mel_db.mean()) / (mel_db.std() + 1e-6)

    return mel_db  # shape: (1, n_mels, time_steps)

# ── Endpoints ──────────────────────────────────────────────────
@app.get("/health")
def health():
    return {"status": "ok", "model_loaded": model_loaded, "device": str(device)}

@app.post("/predict")
async def predict(audio: UploadFile = File(...)):
    if not model_loaded:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        audio_bytes = await audio.read()
        if len(audio_bytes) < 100:
            raise HTTPException(status_code=400, detail="Audio file too small")

        # Preprocess
        mel_tensor = preprocess_audio(audio_bytes).to(device)
        # mel_tensor shape: (1, n_mels, time_steps), model expects (batch, 1, n_mels, time)
        mel_tensor = mel_tensor.unsqueeze(0)  # add batch dim → (1, 1, n_mels, time)

        # Inference
        with torch.no_grad():
            logits = model(mel_tensor)
            probs = torch.sigmoid(logits).squeeze(0)  # (38,)

        # Get top 5 predictions
        top5_values, top5_indices = torch.topk(probs, k=min(5, NUM_CLASSES))
        top5 = {LABEL_NAMES[idx]: round(val.item(), 4) for idx, val in zip(top5_indices, top5_values)}

        # Best prediction
        best_idx = top5_indices[0].item()
        predicted_class = LABEL_NAMES[best_idx]
        confidence = round(top5_values[0].item(), 4)

        return {
            "predicted_class": predicted_class,
            "confidence": confidence,
            "top_5": top5,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {str(e)}")
