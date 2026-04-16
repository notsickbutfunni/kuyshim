# CNN vs CRNN Comparison

| Model | Top-1 | Top-3 | Top-5 | Mean Latency (ms) | Median Latency (ms) | P95 Latency (ms) | Params | Inference Complexity |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| CNN minimal_v2 | 0.3445 | 0.5981 | 0.6986 | 6.28 | 5.99 | 8.80 | 159,880 | low |
| CRNN crnn_v1 | 0.0861 | 0.2632 | 0.3206 | 41.16 | 41.07 | 47.25 | 1,457,768 | medium |
