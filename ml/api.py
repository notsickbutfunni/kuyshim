"""
api.py
──────
FastAPI microservice for ML inference.

Endpoints:
  POST /predict   — Chord/fret classification from audio
  POST /evaluate  — Performance evaluation (user vs reference audio)
  GET  /health    — Health check
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Dict, Optional

from inference import load_model, is_loaded, predict_chord, evaluate_performance

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# ── Startup / Shutdown ───────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the ML model once at startup."""
    logger.info("Loading ML model...")
    try:
        load_model()
        logger.info("ML model loaded successfully.")
    except FileNotFoundError as e:
        logger.error("Could not load model: %s", e)
        logger.warning("ML service will start but predictions will fail.")
    yield


app = FastAPI(
    title="Dombra ML Service",
    description="Audio analysis and chord recognition for Dombra Master",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Response schemas ─────────────────────────────────────────────
class PredictionResponse(BaseModel):
    predicted_class: str
    confidence: float
    top_5: Dict[str, float]


class EvaluationResponse(BaseModel):
    accuracy: float
    timing_offset: float
    note_consistency: float
    predicted_chord: str
    reference_chord: str
    final_score: float


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool


# ── Endpoints ────────────────────────────────────────────────────
@app.get("/health", response_model=HealthResponse)
def health_check():
    return HealthResponse(
        status="ok",
        model_loaded=is_loaded(),
    )


@app.post("/predict", response_model=PredictionResponse)
async def predict_endpoint(audio: UploadFile = File(...)):
    """
    Predict the chord/fret being played in the uploaded audio file.

    Accepts WAV, MP3, OGG, M4A formats.
    """
    if not is_loaded():
        raise HTTPException(
            status_code=503,
            detail="ML model is not loaded. Check server logs.",
        )

    try:
        audio_bytes = await audio.read()
        if len(audio_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty audio file")

        result = predict_chord(audio_bytes)

        # Get top 5 predictions for the response
        sorted_probs = sorted(
            result.all_probabilities.items(),
            key=lambda x: x[1],
            reverse=True,
        )[:5]
        top_5 = {k: round(v, 4) for k, v in sorted_probs}

        return PredictionResponse(
            predicted_class=result.predicted_class,
            confidence=round(result.confidence, 4),
            top_5=top_5,
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception("Prediction error")
        raise HTTPException(status_code=500, detail=f"Inference failed: {str(e)}")


@app.post("/evaluate", response_model=EvaluationResponse)
async def evaluate_endpoint(
    user_audio: UploadFile = File(...),
    reference_audio: UploadFile = File(...),
):
    """
    Evaluate the user's performance by comparing their audio against a reference.

    Returns accuracy, timing_offset, note_consistency, and final_score.
    """
    if not is_loaded():
        raise HTTPException(
            status_code=503,
            detail="ML model is not loaded. Check server logs.",
        )

    try:
        user_bytes = await user_audio.read()
        ref_bytes = await reference_audio.read()

        if len(user_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty user audio file")
        if len(ref_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty reference audio file")

        result = evaluate_performance(user_bytes, ref_bytes)

        return EvaluationResponse(
            accuracy=result.accuracy,
            timing_offset=result.timing_offset,
            note_consistency=result.note_consistency,
            predicted_chord=result.predicted_chord,
            reference_chord=result.reference_chord,
            final_score=result.final_score,
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.exception("Evaluation error")
        raise HTTPException(status_code=500, detail=f"Evaluation failed: {str(e)}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api:app", host="0.0.0.0", port=8001, reload=True)
