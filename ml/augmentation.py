import os
import librosa
import soundfile as sf
import numpy as np
from audiomentations import Compose, PitchShift, TimeStretch, AddGaussianNoise, RoomSimulator

class DombraAugmenter:
    """
    Audio augmentation pipeline tailored for Dombra AMT (Automatic Music Transcription).
    Focuses on pitch shifting, time stretching, room acoustics, and realistic noise
    to synthetically expand the 190-sample dataset without breaking musical identity.
    """
    def __init__(self, sample_rate=22050):
        self.sample_rate = sample_rate
        
        # Define the augmentation pipeline
        self.augment = Compose([
            # 1. Pitch Shifting: +/- 2 semitones to keep the instrument's formant realistic
            PitchShift(
                min_semitones=-2,
                max_semitones=2,
                p=0.5
            ),
            # 2. Time Stretching: 0.8x to 1.2x to simulate different "kuy" tempos
            TimeStretch(
                min_rate=0.8,
                max_rate=1.2,
                p=0.5,
                leave_length_unchanged=False # Length changes, useful for individual notes
            ),
            # 3. Room Impulse Response: Simulating different acoustic environments
            RoomSimulator(
                min_target_rt60=0.1,  # Dry room
                max_target_rt60=0.6,  # Slightly reverberant room (e.g. hall)
                p=0.4
            ),
            # 4. Background Noise: Low-level noise for real-world robustness
            AddGaussianNoise(
                min_amplitude=0.001,
                max_amplitude=0.015,
                p=0.3
            )
        ])

    def process_file(self, input_path, output_path, variations=3):
        """
        Reads an audio file, applies random augmentations, and saves `variations` versions.
        """
        audio, sr = librosa.load(input_path, sr=self.sample_rate)
        
        # Ensure output directory exists
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        base_name, ext = os.path.splitext(os.path.basename(output_path))
        dir_name = os.path.dirname(output_path)

        for i in range(variations):
            augmented_audio = self.augment(samples=audio, sample_rate=sr)
            
            # Normalize to prevent clipping after room simulation/noise
            max_amp = np.max(np.abs(augmented_audio))
            if max_amp > 1.0:
                augmented_audio /= max_amp

            out_file = os.path.join(dir_name, f"{base_name}_aug{i+1}{ext}")
            sf.write(out_file, augmented_audio, sr)
            print(f"Saved augmented variation to: {out_file}")

if __name__ == "__main__":
    # Example usage:
    # augmenter = DombraAugmenter(sample_rate=22050)
    # augmenter.process_file("data/raw/s1_all_variations.wav", "data/augmented/s1_all_variations.wav", variations=3)
    print("DombraAugmenter is ready. Use this in your dataloader or offline generation script.")
