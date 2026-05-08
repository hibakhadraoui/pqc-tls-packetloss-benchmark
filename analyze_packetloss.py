import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import os
import csv

results_dir = "/home/hibalenovo/pqc-tls/results_packetloss"
graphs_dir = "/home/hibalenovo/pqc-tls/graphs_packetloss"
os.makedirs(graphs_dir, exist_ok=True)

algorithms = ["x25519", "mlkem768", "frodo640aes", "bikel1", "X25519MLKEM768"]
labels = ["X25519 (classical)", "ML-KEM-768", "FrodoKEM-640-AES", "BIKE-L1", "X25519+ML-KEM-768 (hybrid)"]
loss_rates = [0, 1, 3, 5, 10]

data = {}
for alg in algorithms:
    data[alg] = {}
    for loss in loss_rates:
        filepath = os.path.join(results_dir, f"{alg}_loss{loss}.csv")
        if os.path.exists(filepath):
            with open(filepath) as f:
                reader = csv.reader(f)
                next(reader)
                vals = [float(row[0]) for row in reader if row]
                data[alg][loss] = vals

plt.figure(figsize=(10, 6))
for alg, label in zip(algorithms, labels):
    medians = [np.median(data[alg][loss]) for loss in loss_rates]
    plt.plot(loss_rates, medians, marker='o', label=label, linewidth=2)
plt.xlabel("Packet Loss Rate (%)", fontsize=12)
plt.ylabel("Median Handshake Time (ms)", fontsize=12)
plt.title("PQC TLS Handshake Time vs Packet Loss (RTT=100ms)", fontsize=14)
plt.legend()
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(graphs_dir, "median_vs_packetloss.png"), dpi=150)
plt.close()

plt.figure(figsize=(10, 6))
for alg, label in zip(algorithms, labels):
    p95s = [np.percentile(data[alg][loss], 95) for loss in loss_rates]
    plt.plot(loss_rates, p95s, marker='s', label=label, linewidth=2)
plt.xlabel("Packet Loss Rate (%)", fontsize=12)
plt.ylabel("95th Percentile Handshake Time (ms)", fontsize=12)
plt.title("PQC TLS Handshake Time (P95) vs Packet Loss (RTT=100ms)", fontsize=14)
plt.legend()
plt.grid(True, alpha=0.3)
plt.tight_layout()
plt.savefig(os.path.join(graphs_dir, "p95_vs_packetloss.png"), dpi=150)
plt.close()

print(f"\n{'Algorithm':<25} {'0%':>8} {'1%':>8} {'3%':>8} {'5%':>8} {'10%':>8}")
print("-" * 65)
for alg, label in zip(algorithms, labels):
    row = f"{label:<25}"
    for loss in loss_rates:
        row += f" {np.median(data[alg][loss]):>7.1f}"
    print(row)

print(f"\n{'95th Percentile':>25}")
print(f"{'Algorithm':<25} {'0%':>8} {'1%':>8} {'3%':>8} {'5%':>8} {'10%':>8}")
print("-" * 65)
for alg, label in zip(algorithms, labels):
    row = f"{label:<25}"
    for loss in loss_rates:
        row += f" {np.percentile(data[alg][loss], 95):>7.1f}"
    print(row)

print(f"\nGraphs saved to {graphs_dir}")
