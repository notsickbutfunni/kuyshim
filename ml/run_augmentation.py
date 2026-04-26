import os
import glob
import shutil
from augmentation import DombraAugmenter

def main():
    # Base directory based on script location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(script_dir, 'data', 'segmented')
    output_dir = os.path.join(script_dir, 'data', 'augmented')
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    augmenter = DombraAugmenter(sample_rate=22050)
    
    # Get all .wav files from segmented folder
    wav_files = glob.glob(os.path.join(input_dir, '*.wav'))
    total_files = len(wav_files)
    
    if total_files == 0:
        print(f"No .wav files found in {input_dir}")
        return
        
    print(f"Found {total_files} files to augment.")
    print(f"Augmented files will be saved to: {output_dir}")
    print("Starting augmentation process (this might take a few minutes)...")
    
    for i, file_path in enumerate(wav_files):
        filename = os.path.basename(file_path)
        
        # Prevent data leakage: Do not augment Validation ('ringing') or Test ('human') sets
        if 'ringing' in filename or 'human' in filename:
            continue
            
        out_path = os.path.join(output_dir, filename)
        
        # Copy original file to the augmented folder to have the complete dataset in one place
        shutil.copy2(file_path, out_path)
        
        # Apply augmentation (generates _aug1, _aug2, _aug3)
        # This will create files like: s1_f00_soft_aug1.wav, etc.
        augmenter.process_file(file_path, out_path, variations=3)
        
        if (i + 1) % 20 == 0:
            print(f"Processed {i + 1}/{total_files} files...")
            
    print("\nData augmentation complete!")
    print(f"Total files in {output_dir}: {len(os.listdir(output_dir))}")

if __name__ == "__main__":
    main()
