import numpy as np

from src.chroma_extractor import ChromaConfig, compute_chroma_from_audio


def test_compute_chroma_shape():
    sr = 44100
    t = np.linspace(0.0, 2.0, int(sr * 2.0), endpoint=False)
    audio = 0.5 * np.sin(2.0 * np.pi * 220.0 * t).astype(np.float32)

    config = ChromaConfig()
    chroma = compute_chroma_from_audio(audio, sr, config)

    assert chroma.shape == (config.n_chroma, config.target_frames)