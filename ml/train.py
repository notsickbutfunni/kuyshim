import os
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from dataset import DombraDataset, get_data_splits
from model import DombraResNet
import numpy as np
from sklearn.metrics import f1_score, accuracy_score

def train_epoch(model, dataloader, criterion, optimizer, device):
    model.train()
    running_loss = 0.0
    all_preds = []
    all_targets = []
    
    for inputs, targets in dataloader:
        inputs, targets = inputs.to(device), targets.to(device)
        
        optimizer.zero_grad()
        outputs = model(inputs)
        
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item() * inputs.size(0)
        
        # For multi-label classification, applying sigmoid and thresholding at 0.5
        preds = torch.sigmoid(outputs) > 0.5
        all_preds.append(preds.cpu().numpy())
        all_targets.append(targets.cpu().numpy())
        
    epoch_loss = running_loss / len(dataloader.dataset)
    all_preds = np.vstack(all_preds)
    all_targets = np.vstack(all_targets)
    
    # Compute metrics
    # average='macro' calculates metrics for each label, and finds their unweighted mean. 
    # Important for imbalanced data.
    macro_f1 = f1_score(all_targets, all_preds, average='macro', zero_division=0)
    
    return epoch_loss, macro_f1

def evaluate(model, dataloader, criterion, device):
    model.eval()
    running_loss = 0.0
    all_preds = []
    all_targets = []
    
    with torch.no_grad():
        for inputs, targets in dataloader:
            inputs, targets = inputs.to(device), targets.to(device)
            
            outputs = model(inputs)
            loss = criterion(outputs, targets)
            
            running_loss += loss.item() * inputs.size(0)
            
            preds = torch.sigmoid(outputs) > 0.5
            all_preds.append(preds.cpu().numpy())
            all_targets.append(targets.cpu().numpy())
            
    epoch_loss = running_loss / len(dataloader.dataset)
    all_preds = np.vstack(all_preds)
    all_targets = np.vstack(all_targets)
    
    macro_f1 = f1_score(all_targets, all_preds, average='macro', zero_division=0)
    
    # Exact match ratio (accuracy) across all labels
    exact_accuracy = accuracy_score(all_targets, all_preds)
    
    return epoch_loss, macro_f1, exact_accuracy

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_dir = os.path.join(script_dir, 'data')
    save_dir = os.path.join(script_dir, 'models', 'trained_models')
    os.makedirs(save_dir, exist_ok=True)
    
    # Hyperparameters
    batch_size = 32
    num_epochs = 30
    learning_rate = 5e-5  # Lower learning rate for fine-tuning
    
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"Using device: {device}")
    
    # Data Setup
    print("Preparing datasets...")
    train_files, val_files, test_files = get_data_splits(data_dir)
    print(f"Dataset split -> Train: {len(train_files)}, Val: {len(val_files)}, Test: {len(test_files)}")
    
    train_dataset = DombraDataset(train_files, augment=True)
    val_dataset = DombraDataset(val_files, augment=False)
    
    train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, num_workers=0)
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False, num_workers=0)
    
    # Model Setup
    # Unfreeze the backbone for fine-tuning
    model = DombraResNet(freeze_backbone=False).to(device)
    
    # Load the baseline weights
    baseline_path = os.path.join(save_dir, 'best_dombra_baseline.pth')
    if os.path.exists(baseline_path):
        print(f"Loading baseline weights from {baseline_path}")
        state_dict = torch.load(baseline_path, map_location=device, weights_only=True)
        # Adapt state_dict keys for the newly added Dropout layer in Sequential
        if "backbone.fc.weight" in state_dict:
            state_dict["backbone.fc.1.weight"] = state_dict.pop("backbone.fc.weight")
            state_dict["backbone.fc.1.bias"] = state_dict.pop("backbone.fc.bias")
        model.load_state_dict(state_dict)
    else:
        print("Warning: Could not find baseline weights. Starting from scratch.")
        
    # Use BCEWithLogitsLoss for multi-label classification
    criterion = nn.BCEWithLogitsLoss()
    # Added weight decay (L2 regularization) to reduce overfitting
    optimizer = optim.Adam(model.parameters(), lr=learning_rate, weight_decay=1e-4)
    
    # Learning Rate Scheduler: reduces LR if validation F1 stops improving
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', factor=0.5, patience=2)
    
    best_val_f1 = 0.0
    patience = 6  # Early stopping patience
    epochs_no_improve = 0
    
    print("Starting training...")
    for epoch in range(num_epochs):
        train_loss, train_f1 = train_epoch(model, train_loader, criterion, optimizer, device)
        val_loss, val_f1, val_acc = evaluate(model, val_loader, criterion, device)
        
        print(f"Epoch [{epoch+1}/{num_epochs}] "
              f"Train Loss: {train_loss:.4f}, Train F1: {train_f1:.4f} | "
              f"Val Loss: {val_loss:.4f}, Val F1: {val_f1:.4f}, Val Exact Acc: {val_acc:.4f}")
              
        # Step the scheduler
        scheduler.step(val_f1)
              
        # Save best model and Early Stopping logic
        if val_f1 > best_val_f1:
            best_val_f1 = val_f1
            epochs_no_improve = 0
            torch.save(model.state_dict(), os.path.join(save_dir, 'best_dombra_finetuned.pth'))
            print(" -> Model saved!")
        else:
            epochs_no_improve += 1
            if epochs_no_improve >= patience:
                print(f"\nEarly stopping triggered after {epoch+1} epochs! Validation F1 hasn't improved for {patience} epochs.")
                break
            
    print("Training complete!")

if __name__ == "__main__":
    main()
