import numpy as np

from src.augmentation import AudioAugmentor, AugmentationConfig, mix_background_noise


def test_mix_background_noise_snr_is_reasonable():
    sr = 22050
    t = np.linspace(0.0, 1.0, int(sr), endpoint=False)
    audio = 0.2 * np.sin(2.0 * np.pi * 220.0 * t).astype(np.float32)
    noise = np.random.default_rng(7).normal(0.0, 1.0, size=len(audio)).astype(np.float32)

    target_snr = 20.0
    mixed = mix_background_noise(audio, noise, snr_db=target_snr)
    noise_part = mixed - audio

    signal_rms = float(np.sqrt(np.mean(audio**2)) + 1e-8)
    noise_rms = float(np.sqrt(np.mean(noise_part**2)) + 1e-8)
    snr = 20.0 * np.log10(signal_rms / noise_rms)

    assert len(mixed) == len(audio)
    assert np.isfinite(snr)
    assert abs(snr - target_snr) < 1.5


def test_audio_augmentor_preserves_shape_and_range():
    sr = 22050
    t = np.linspace(0.0, 1.0, int(sr), endpoint=False)
    audio = 0.3 * np.sin(2.0 * np.pi * 440.0 * t).astype(np.float32)

    cfg = AugmentationConfig(
        p_time_stretch=1.0,
        p_pitch_shift=1.0,
        p_background_noise=1.0,
        max_pitch_cents=15.0,
        seed=123,
    )
    augmentor = AudioAugmentor(cfg)
    augmented, meta = augmentor.augment(audio, sr)

    assert len(augmented) == len(audio)
    assert augmented.dtype == np.float32
    assert float(np.max(np.abs(augmented))) <= 1.0 + 1e-5
    assert "time_stretch_rate" in meta
    assert "pitch_shift_cents" in meta
    assert "noise_snr_db" in meta
