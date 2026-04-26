import os
import glob
import numpy as np
import librosa
import soundfile as sf
from itertools import product

def generate_dombra_chord(note_1, note_2, sample_rate=22050):
    """
    Generates a synthetic dombra chord/interval by overlaying two notes
    with a realistic micro-delay (strum effect).
    """
    # 1. Randomize a tiny delay (10-40ms) to simulate a real strum
    delay_samples = int(np.random.uniform(0.01, 0.04) * sample_rate)
    
    # 2. Align lengths
    max_len = max(len(note_1), len(note_2) + delay_samples)
    combined = np.zeros(max_len)
    
    # 3. Apply a slight volume difference (the bottom string is often louder or the melody string)
    # We can assume note_1 is played first (e.g., top string), note_2 is played second
    combined[:len(note_1)] += note_1 * 1.0
    combined[delay_samples : delay_samples + len(note_2)] += note_2 * 0.8
    
    # 4. Normalize to prevent clipping
    max_val = np.max(np.abs(combined))
    if max_val > 0:
        combined = combined / max_val
        
    return combined

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_dir = os.path.join(script_dir, 'data', 'segmented')
    output_dir = os.path.join(script_dir, 'data', 'chords')
    
    os.makedirs(output_dir, exist_ok=True)
    
    sample_rate = 22050
    
    # We expect files like s1_f00_soft.wav, s2_f05_diff.wav
    # Let's group them by string and variation
    all_files = glob.glob(os.path.join(input_dir, '*.wav'))
    
    if not all_files:
        print(f"No .wav files found in {input_dir}")
        return
        
    # Parse files into a dictionary: {string: {fret: {variation: filepath}}}
    # Strings: 's1', 's2'
    # Frets: 'f00', 'f01', ... 'f19'
    # Variations: 'soft', 'strong', 'diff', 'ringing', 'human_var'
    
    parsed_data = {'s1': {}, 's2': {}}
    variations = set()
    
    for fpath in all_files:
        basename = os.path.basename(fpath) # e.g. s1_f00_soft.wav
        name, ext = os.path.splitext(basename)
        parts = name.split('_', 2) # ['s1', 'f00', 'soft'] or ['s1', 'f00', 'human_var']
        if len(parts) >= 3:
            s = parts[0]
            f = parts[1]
            v = parts[2]
            
            if s in parsed_data:
                if f not in parsed_data[s]:
                    parsed_data[s][f] = {}
                parsed_data[s][f][v] = fpath
                variations.add(v)
                
    # We want to generate all possible intervals: s1_fXX + s2_fYY
    # We match the variations so 'soft' mixes with 'soft', etc.
    
    generated_count = 0
    
    for var in variations:
        print(f"Generating intervals for variation: {var}")
        
        # Iterate over all frets in s1
        for fret1, var_dict1 in parsed_data['s1'].items():
            if var not in var_dict1:
                continue
                
            note1_path = var_dict1[var]
            note1_audio, sr = librosa.load(note1_path, sr=sample_rate)
            
            # Iterate over all frets in s2
            for fret2, var_dict2 in parsed_data['s2'].items():
                if var not in var_dict2:
                    continue
                    
                note2_path = var_dict2[var]
                note2_audio, _ = librosa.load(note2_path, sr=sample_rate)
                
                # Generate chord: s1 is played first, then s2
                chord_audio = generate_dombra_chord(note1_audio, note2_audio, sample_rate)
                
                # Save it: chord_s1_{fret1}_s2_{fret2}_{var}.wav
                out_name = f"chord_s1_{fret1}_s2_{fret2}_{var}.wav"
                out_path = os.path.join(output_dir, out_name)
                sf.write(out_path, chord_audio, sample_rate)
                generated_count += 1
                
    print(f"\nGenerated {generated_count} interval combinations in {output_dir}")

if __name__ == "__main__":
    main()
