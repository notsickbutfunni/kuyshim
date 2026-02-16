import numpy as np

from src.feature_extractor import extract_features


def test_extract_features_shapes():
    sr = 44100
    t = np.linspace(0.0, 1.0, int(sr * 1.0), endpoint=False)
    audio = 0.5 * np.sin(2.0 * np.pi * 440.0 * t).astype(np.float32)

    features = extract_features(audio, sr)
    assert set(features.keys()) == {"zcr", "rms", "centroid", "rolloff"}

    lengths = {len(v) for v in features.values()}
    assert len(lengths) == 1
    assert next(iter(lengths)) > 0
