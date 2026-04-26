import os
import shutil
import random
from collections import defaultdict
from augmentation import DombraAugmenter

def main():
    random.seed(42) # For reproducible splits
    
    # Base directory is 'ml' based on the path
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(script_dir, 'data', 'segmented_20')
    train_dir = os.path.join(script_dir, 'data', 'train')
    val_dir = os.path.join(script_dir, 'data', 'val')
    test_dir = os.path.join(script_dir, 'data', 'test')
    
    # Create directories if they don't exist
    for d in [train_dir, val_dir, test_dir]:
        os.makedirs(d, exist_ok=True)
        
    augmenter = DombraAugmenter(sample_rate=22050)
    
    # Group files by note (e.g., 's1_f00')
    notes = defaultdict(list)
    for filename in os.listdir(input_dir):
        if not filename.endswith('.wav'):
            continue
        # Split by '_' and get the first two parts
        parts = filename.split('_')
        if len(parts) >= 2:
            note_key = f"{parts[0]}_{parts[1]}"
            notes[note_key].append(filename)
            
    # Split and process
    for note_key, files in notes.items():
        # files contains 5 files per note
        random.shuffle(files)
        
        # 3 for train, 1 for val, 1 for test
        train_files = files[:3]
        val_files = files[3:4]
        test_files = files[4:]
        
        # Copy val files
        for f in val_files:
            shutil.copy2(os.path.join(input_dir, f), os.path.join(val_dir, f))
            
        # Copy test files
        for f in test_files:
            shutil.copy2(os.path.join(input_dir, f), os.path.join(test_dir, f))
            
        # Process train files (copy original, then augment)
        for f in train_files:
            src_path = os.path.join(input_dir, f)
            dest_path = os.path.join(train_dir, f)
            shutil.copy2(src_path, dest_path)
            
            # Augment
            augmenter.process_file(src_path, dest_path, variations=3)
            
    print("Data splitting and augmentation complete!")

if __name__ == "__main__":
    main()
