import os
import glob
import re
import torch
import torchaudio
from torch.utils.data import Dataset

class DombraDataset(Dataset):
    def __init__(self, file_paths, sample_rate=22050, n_mels=128, n_fft=1024, hop_length=256, max_len_sec=2.0, augment=False):
        """
        Args:
            file_paths (list): List of file paths to audio files (.wav).
            sample_rate (int): Target sample rate.
            n_mels (int): Number of mel filterbanks.
            n_fft (int): FFT size.
            hop_length (int): Hop length for STFT.
            max_len_sec (float): Max audio length in seconds. Will pad/trim to this.
        """
        self.file_paths = file_paths
        self.sample_rate = sample_rate
        self.max_len_samples = int(sample_rate * max_len_sec)
        self.augment = augment
        
        # Setup torchaudio transforms
        self.mel_spectrogram = torchaudio.transforms.MelSpectrogram(
            sample_rate=sample_rate,
            n_fft=n_fft,
            hop_length=hop_length,
            n_mels=n_mels
        )
        self.amplitude_to_db = torchaudio.transforms.AmplitudeToDB()
        
        # Initialize heavy augmentation transforms ONCE here to prevent massive slowdowns
        if self.augment:
            self.pitch_shift_up = torchaudio.transforms.PitchShift(sample_rate, n_steps=1)
            self.pitch_shift_down = torchaudio.transforms.PitchShift(sample_rate, n_steps=-1)

    def __len__(self):
        return len(self.file_paths)

    def parse_labels(self, filename):
        """
        Parses filename to extract multi-hot labels.
        Labels: 0-18 for s1_f00 to s1_f18, 19-37 for s2_f00 to s2_f18
        """
        labels = torch.zeros(38, dtype=torch.float32)
        
        # Matches all occurrences of s[1 or 2]_f[00 to 19]
        matches = re.findall(r'(s[12])_f(\d{2})', filename)
        
        for string_id, fret_id in matches:
            fret_num = int(fret_id)
            if string_id == 's1':
                idx = fret_num
            else:
                idx = 19 + fret_num
                
            if 0 <= idx < 38:
                labels[idx] = 1.0
                
        return labels

    @torch.no_grad()
    def __getitem__(self, idx):
        path = self.file_paths[idx]
        
        # 1. Load audio
        waveform, sr = torchaudio.load(path)
        
        # 2. Resample if necessary
        if sr != self.sample_rate:
            resampler = torchaudio.transforms.Resample(orig_freq=sr, new_freq=self.sample_rate)
            waveform = resampler(waveform)
            
        # 3. Convert to mono if it's stereo
        if waveform.shape[0] > 1:
            waveform = torch.mean(waveform, dim=0, keepdim=True)
            
        # 4. Extract label from filename
        filename = os.path.basename(path)
        labels = self.parse_labels(filename)

        # 5. Apply dynamic data augmentations on the fly
        if self.augment:
            # A) Pitch Shift (+/- 1 semitone)
            if torch.rand(1).item() < 0.5:
                # Randomly choose -1 or 1
                n_steps = 1 if torch.rand(1).item() < 0.5 else -1
                
                # Check if shifting pushes the label out of fret range (0-18 or 19-37)
                active_indices = torch.nonzero(labels).flatten().tolist()
                can_shift = True
                new_labels = torch.zeros_like(labels)
                
                for idx in active_indices:
                    if idx < 19:
                        if not (0 <= idx + n_steps <= 18):
                            can_shift = False
                            break
                    else:
                        if not (19 <= idx + n_steps <= 37):
                            can_shift = False
                            break
                    new_labels[idx + n_steps] = 1.0
                    
                if can_shift:
                    if n_steps == 1:
                        waveform = self.pitch_shift_up(waveform)
                    else:
                        waveform = self.pitch_shift_down(waveform)
                    labels = new_labels

            # B) White Noise
            if torch.rand(1).item() < 0.5:
                noise_level = torch.rand(1).item() * 0.015
                waveform += torch.randn_like(waveform) * noise_level

            # C) Room Reverb approximation (slight echo/delay)
            if torch.rand(1).item() < 0.4:
                delay_samples = int(torch.randint(200, 800, (1,)).item())
                decay = torch.rand(1).item() * 0.3 + 0.1
                if waveform.shape[1] > delay_samples:
                    delayed = torch.zeros_like(waveform)
                    delayed[:, delay_samples:] = waveform[:, :-delay_samples]
                    waveform = waveform + decay * delayed
            
        # 6. Pad or truncate length
        if waveform.shape[1] > self.max_len_samples:
            waveform = waveform[:, :self.max_len_samples]
        elif waveform.shape[1] < self.max_len_samples:
            padding = self.max_len_samples - waveform.shape[1]
            waveform = torch.nn.functional.pad(waveform, (0, padding))
            
        # 5. Extract Mel Spectrogram
        mel_spec = self.mel_spectrogram(waveform)
        mel_spec_db = self.amplitude_to_db(mel_spec)
        
        # 8. Normalize per instance (zero mean, unit variance)
        mel_spec_db = (mel_spec_db - mel_spec_db.mean()) / (mel_spec_db.std() + 1e-6)
        
        return mel_spec_db, labels


def get_data_splits(data_dir):
    """
    Returns train, val, test lists of absolute file paths.
    Uses 'variation' in the filename to ensure NO DATA LEAKAGE across splits.
    """
    all_files = []
    # Collect from all 3 directories
    for sub in ['segmented', 'augmented', 'chords']:
        all_files.extend(glob.glob(os.path.join(data_dir, sub, '*.wav')))
        
    train_files = []
    val_files = []
    test_files = []
    
    # Split rules:
    # Any file containing 'ringing' goes to Val
    # Any file containing 'human' goes to Test
    # Everything else (soft, strong, diff, and their augments) goes to Train
    for f in all_files:
        basename = os.path.basename(f)
        if 'ringing' in basename:
            val_files.append(f)
        elif 'human' in basename:
            test_files.append(f)
        else:
            train_files.append(f)
            
    return train_files, val_files, test_files

if __name__ == "__main__":
    # Quick test to verify splits and label extraction
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(script_dir, 'data')
    
    train_files, val_files, test_files = get_data_splits(data_dir)
    print(f"Train files: {len(train_files)}")
    print(f"Val files: {len(val_files)}")
    print(f"Test files: {len(test_files)}")
    
    if len(train_files) > 0:
        dataset = DombraDataset(train_files)
        spec, label = dataset[0]
        print(f"Spectrogram shape: {spec.shape}")
        print(f"Label shape: {label.shape}")
        print(f"Sample file: {os.path.basename(train_files[0])}")
        print(f"Active classes for sample: {torch.nonzero(label).squeeze().tolist()}")
