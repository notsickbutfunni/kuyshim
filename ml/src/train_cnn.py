from __future__ import annotations

import argparse
from typing import List, Tuple

import numpy as np
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset
from tqdm import tqdm
from .model import build_model


class ChromaDataset(Dataset):
    def __init__(self, data: List[Tuple[np.ndarray, int]]) -> None:
        self.data = data

    def __len__(self) -> int:
        return len(self.data)

    def __getitem__(self, idx: int) -> Tuple[torch.Tensor, torch.Tensor]:
        chroma, label = self.data[idx]
        x = torch.tensor(chroma, dtype=torch.float32).unsqueeze(0)
        y = torch.tensor(label, dtype=torch.long)
        return x, y


def load_dataset(path: str) -> List[Tuple[np.ndarray, int]]:
    raw = np.load(path, allow_pickle=True)
    return list(raw)


def train(dataset_path: str, output_path: str, epochs: int = 5, batch_size: int = 16) -> None:
    data = load_dataset(dataset_path)
    if len(data) == 0:
        print("Dataset is empty. Add labeled clips and rebuild the dataset.")
        return

    split = max(1, int(len(data) * 0.8))
    train_data = data[:split]
    val_data = data[split:]

    train_loader = DataLoader(ChromaDataset(train_data), batch_size=batch_size, shuffle=True)
    val_loader = DataLoader(ChromaDataset(val_data), batch_size=batch_size)

    model = build_model(num_classes=len())
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model.to(device)

    optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    loss_fn = nn.CrossEntropyLoss()

    for epoch in range(epochs):
        model.train()
        total_loss = 0.0
        for x, y in tqdm(train_loader, desc=f"Epoch {epoch + 1}/{epochs}"):
            x = x.to(device)
            y = y.to(device)
            optimizer.zero_grad()
            logits = model(x)
            loss = loss_fn(logits, y)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        model.eval()
        correct = 0
        total = 0
        with torch.no_grad():
            for x, y in val_loader:
                x = x.to(device)
                y = y.to(device)
                logits = model(x)
                preds = torch.argmax(logits, dim=1)
                correct += (preds == y).sum().item()
                total += y.size(0)

        acc = (correct / total) if total else 0.0
        print(f"Epoch {epoch + 1} loss {total_loss:.4f} val_acc {acc:.4f}")

    torch.save(model.state_dict(), output_path)


def main() -> None:
    parser = argparse.ArgumentParser(description="Train chord CNN from chroma dataset.")
    parser.add_argument("--data", required=True, help="Path to dataset .npy")
    parser.add_argument("--out", required=True, help="Path to save model .pth")
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--batch", type=int, default=16)
    args = parser.parse_args()

    train(args.data, args.out, epochs=args.epochs, batch_size=args.batch)


if __name__ == "__main__":
    main()
