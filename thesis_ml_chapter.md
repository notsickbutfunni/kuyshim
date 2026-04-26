# Chapter X: Machine Learning Architecture and Experiments for Automatic Dombra Transcription

## 1. Introduction
The Kuyshim platform aims to provide an interactive, real-time learning environment for the Kazakh dombra. The core technical challenge of this platform is the Automatic Music Transcription (AMT) system. Unlike Western instruments such as the piano or monophonic instruments like the flute, the dombra presents unique acoustic complexities. It is a two-stringed fretless/tied-fret instrument where performance heavily relies on *kuy*—a traditional technique involving the simultaneous striking of both strings to produce overlapping harmonics, often accompanied by micro-timing variations (strumming delays). 

Traditional Digital Signal Processing (DSP) methods, such as standard pitch tracking or simple onset detection, fail to accurately isolate multi-string harmonic overlaps. Consequently, a Deep Learning approach utilizing Convolutional Neural Networks (CNNs) over Mel-spectrograms was adopted. This chapter details the architectural decisions, dataset engineering, and iterative experiments conducted to develop a robust, multi-label classification model capable of transcribing dombra performances in real-time.

## 2. Dataset Engineering and Augmentation Strategy
Deep learning models are fundamentally constrained by the quality and diversity of their training data. Initial attempts at training an AMT model for the dombra revealed significant overfitting, primarily due to the limited variance in the base dataset of cleanly segmented notes. To address this, a comprehensive, multi-stage augmentation strategy was implemented.

### 2.1 Base Data and Zero-Leakage Splitting
The raw dataset comprised meticulously hand-segmented recordings of individual dombra notes spanning two strings and 19 frets (yielding 38 distinct classes). To ensure the model learned generalized acoustic features rather than memorizing recording conditions, a strict "zero-leakage" data split was enforced. Filenames containing specific metadata markers dictated the split: recordings labeled with `ringing` were exclusively routed to the Validation set, while `human` variations were reserved for the Test set. The remaining samples (e.g., `soft`, `strong`, `diff`) constituted the Training set.

### 2.2 Synthetic *Kuy* Interval Generation
A significant limitation of the raw dataset was the lack of simultaneous string strikes (chords/intervals). Recording every possible combination of 19 frets across two strings is practically unfeasible. 

**Experiment 1: Synthetic Data Integration**
We hypothesized that mathematically overlaying isolated string samples would yield viable multi-label training data. An offline augmentation script (`generate_chords.py`) was developed to cross-multiply isolated notes from String 1 and String 2. 
Crucially, rather than perfectly syncing the waveforms, the algorithm introduces randomized micro-delays (ranging from 10ms to 40ms) and minor volume offsets (where the bottom string is typically slightly louder). This intentionally mimics the natural physics of a human hand strumming across the strings. The integration of this synthetically generated *kuy* data exponentially increased the dataset size and provided the model with necessary overlapping harmonic representations.

### 2.3 Hybrid Offline-Online Augmentation Strategy
To further combat overfitting, a hybrid augmentation pipeline was engineered to balance data diversity with computational efficiency.

**Offline Augmentation (Addressing CPU Bottlenecks):**
Initial implementations attempted to perform context-aware pitch shifting (+/- 1 semitone) dynamically during training. However, executing complex Fast Fourier Transforms (FFTs) for pitch shifting on thousands of audio tensors per epoch created a massive CPU bottleneck, increasing training time exponentially. 
To resolve this engineering trade-off, an offline augmentation script (`run_augmentation.py`) was utilized to pre-compute pitch-shifted variations. Crucially, a rigorous validation check was enforced during this offline generation: any source file containing `ringing` or `human` markers was explicitly skipped. This prevented catastrophic **data leakage**, ensuring that augmented validation and test data never artificially inflated the evaluation metrics.

**On-the-Fly Stochastic Augmentation:**
Computationally inexpensive augmentations were retained dynamically within the `PyTorch` `DataLoader` to ensure the model never sees the exact same sample twice across epochs. During training, the following transforms are applied stochastically:
1.  **White Noise Injection**: Variable amplitude Gaussian noise (up to 1.5%) is added to simulate low-fidelity mobile microphone recordings.
2.  **Room Reverb Simulation**: Randomized delays (200-800 samples) and decay values are applied to mimic varied acoustic environments (e.g., echoing rooms).

## 3. Model Architecture Design
The transcription task was framed as a multi-label image classification problem, where audio waveforms are converted into 2D visual representations (Mel-spectrograms).

### 3.1 Audio Processing Pipeline
Raw waveforms are standardized to a 22050 Hz sampling rate and converted to mono. A sliding window or segment is constrained to a maximum of 2.0 seconds. The signal is transformed using a Mel-spectrogram with 128 filterbanks (`n_mels=128`), an FFT size of 1024, and a hop length of 256. The resulting matrix is scaled logarithmically (Amplitude to DB) and normalized to zero-mean and unit-variance. The final input tensor shape presented to the network is `(1, 128, 173)`.

### 3.2 The ResNet18 Backbone
A `ResNet18` (Residual Network) architecture was selected as the foundational backbone. ResNets mitigate the vanishing gradient problem in deep networks through skip connections. 

**Transfer Learning Application:**
Training a deep CNN from scratch on a limited audio dataset is highly prone to overfitting. Therefore, Transfer Learning was employed using weights pre-trained on the ImageNet dataset. To adapt the architecture for audio:
1.  The initial convolutional layer (`conv1`), originally designed for 3-channel RGB images, was replaced with a 1-channel convolutional layer. The weights for this new layer were initialized by averaging the original 3 channels, preserving the pre-trained edge-detection capabilities.
2.  The final fully connected layer was discarded.

### 3.3 The Multi-Label Classification Head
Because dombra playing frequently involves striking both strings simultaneously, the model must output independent probabilities for all 38 classes (19 frets on String 1, 19 frets on String 2). The classification head was redesigned as a `Sequential` block comprising a `Dropout(p=0.5)` layer—crucial for regularization—followed by a `Linear` layer outputting 38 raw logits.

## 4. Training Methodology and Optimization
The training protocol was iteratively refined through a series of structured experiments aimed at maximizing the model's generalization capabilities.

### 4.1 Loss Function and Metric Selection
**Experiment 2: Loss Function Transition**
Initial models utilized standard `CrossEntropyLoss`, which forces the network to select a single "best" class by applying a softmax distribution. This severely penalized the model when predicting valid *kuy* chords. Transitioning to `BCEWithLogitsLoss` (Binary Cross Entropy) resolved this by applying an independent sigmoid activation to each of the 38 logits, allowing the network to confidently predict multiple active strings simultaneously.

**Evaluation Metric:**
Standard exact-match accuracy is an unreliable metric for multi-label tasks, particularly when datasets exhibit class imbalance. The optimization metric was strictly shifted to the **Macro F1 Score**. The Macro F1 calculates the harmonic mean of precision and recall for *each individual fret*, and then averages them equally, ensuring that rare fret positions are weighted as heavily as common open strings.

### 4.2 Combatting Overfitting
**Experiment 3: Regularization and Learning Rate Dynamics**
Early training runs exhibited classical overfitting: training loss approached zero while validation loss diverged upward. A multi-pronged regularization strategy was deployed:
1.  **Weight Decay**: The `Adam` optimizer was configured with an L2 penalty (Weight Decay = $1\times10^{-4}$), discouraging the network from developing disproportionately large weights.
2.  **Dynamic Scheduling**: A `ReduceLROnPlateau` scheduler was implemented. It actively monitors the Validation F1 score and reduces the learning rate by a factor of 0.5 if no improvement is seen over 2 consecutive epochs. This allows the model to traverse steep gradients quickly in early epochs and fine-tune delicately in later epochs.
3.  **Early Stopping**: A patience threshold of 6 epochs was introduced. If the Validation F1 plateaus for 6 epochs, training is terminated to preserve the optimal weight state.

## 5. Results and Experimental Analysis

The culmination of the data augmentation, architecture modifications, and regularized training loop resulted in a highly stable model. 

### 5.1 Training Convergence
The impact of the regularization techniques is highly visible in the training curves. The convergence rate is stabilized by the dynamic learning rate scheduler, and the gap between training and validation loss is minimized by the aggressive dropout and data augmentation pipelines.

![Training Curves](C:\Users\kaira\kuyshim\ml\models\trained_models\cnn_transfer_v1\training_curves.png)
*Figure 1: Training and Validation curves for Loss and F1 Score across epochs.*

### 5.2 Classification Performance
Evaluation on the isolated test set demonstrated robust precision across both individual notes and synthetic *kuy* chords. The model effectively disambiguates overlapping harmonics. 

![Confusion Matrix](C:\Users\kaira\kuyshim\ml\models\trained_models\cnn_transfer_v1\confusion_matrix.png)
*Figure 2: Confusion Matrix illustrating the true positive predictions against actual dombra frets. The strong diagonal confirms high classification accuracy across the 38 classes.*

*Note: The model consistently correctly predicts open strings (`f00`), which act as the drone in many traditional compositions, while simultaneously capturing the higher-frequency melody notes on the opposing string.*

## 6. Integration into the Real-Time Application
Developing a highly accurate static model is only half the engineering challenge; the model must be operationalized within the Kuyshim platform to serve distinct user experiences.

### 6.1 Real-Time Gaming Inference
For the rhythm game component, latency must remain below 100ms. The system employs a **Sliding Window Technique**. Rather than waiting for a distinct "note" to finish, the Flutter client maintains a continuous 2.0-second ring buffer of the microphone feed. In the optimal deployment architecture, the PyTorch `.pth` model is exported to `TensorFlow Lite` (`.tflite`) and executed locally on the user's mobile device via `tflite_flutter`. This on-device inference bypasses network latency entirely, evaluating the Mel-spectrogram window at 10Hz and matching the predicted multi-hot labels against the expected game notes in real-time.

### 6.2 Offline Transcription Generation
For automated sheet-music transcription of entire performances, the system architecture switches from continuous sliding windows to event-driven inference. 
1.  **Onset Detection**: An algorithmic DSP pass (e.g., Librosa's onset strength) analyzes the full audio file to locate the exact timestamps of string strikes.
2.  **Segmentation**: The audio is dynamically sliced into 2.0-second segments centered around these detected onsets.
3.  **Batch Inference**: These segments are processed through the ResNet18 model to predict the multi-label fret positions.
4.  **Tabulation**: The resulting predictions are thresholded (sigmoid $> 0.5$) and mapped back to their originating timestamps, culminating in a structured JSON output that visually renders traditional dombra tabs within the application.
