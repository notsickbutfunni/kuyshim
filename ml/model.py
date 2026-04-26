import torch
import torch.nn as nn
import torchvision.models as models

class DombraResNet(nn.Module):
    def __init__(self, num_classes=38, freeze_backbone=False):
        """
        ResNet18 baseline model adapted for single-channel audio spectrograms.
        """
        super(DombraResNet, self).__init__()
        
        # Load a pretrained ResNet18
        self.backbone = models.resnet18(weights=models.ResNet18_Weights.DEFAULT)
        
        # 1. Modify the first convolutional layer to accept 1 channel (Mel Spec) instead of 3 (RGB)
        original_conv = self.backbone.conv1
        self.backbone.conv1 = nn.Conv2d(1, 64, kernel_size=7, stride=2, padding=3, bias=False)
        
        # Initialize the new conv layer with the average weights of the 3 channels
        self.backbone.conv1.weight.data = original_conv.weight.data.mean(dim=1, keepdim=True)
        
        # 2. Modify the final fully connected layer for our 38 classes
        num_ftrs = self.backbone.fc.in_features
        # Added Dropout to fight overfitting
        self.backbone.fc = nn.Sequential(
            nn.Dropout(p=0.5),
            nn.Linear(num_ftrs, num_classes)
        )
        
        # 3. Optional: Freeze the backbone for initial fine-tuning (Transfer Learning)
        if freeze_backbone:
            for name, param in self.backbone.named_parameters():
                # Don't freeze the newly created conv1 or the final fc layer
                if 'conv1' not in name and 'fc' not in name:
                    param.requires_grad = False

    def forward(self, x):
        # Input x expected shape: (batch_size, 1, n_mels, time_steps)
        # The output are raw logits. The BCEWithLogitsLoss in train.py handles the sigmoid activation.
        return self.backbone(x)

if __name__ == "__main__":
    # Quick test to ensure shape flows through correctly
    model = DombraResNet()
    dummy_input = torch.randn(4, 1, 128, 173) # Example: Batch=4, Ch=1, Mels=128, Time=173
    output = model(dummy_input)
    print(f"Model output shape: {output.shape} (Expected: [4, 38])")
