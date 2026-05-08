# PQC-TLS Packet Loss Benchmarking — Group L, INFO-F514, ULB 2025/26

**Author:** Hiba Khadraoui (000624402)

Reproduction and extension of:
> Paquin, Stebila, Tamvada — "Benchmarking Post-Quantum Cryptography in TLS", PQCrypto 2020, Springer LNCS vol. 12100

This experiment focuses on **packet loss** as the primary network variable, complementing the latency/bandwidth experiments conducted by Oussama Ebn Atou (available at: https://github.com/usama0print/pqc-tls-benchmarking).

## Research Question

Paquin et al. showed that message size becomes the dominant performance factor under packet loss, with FrodoKEM's 9,616-byte public key requiring 16 IP packets and having a 57% retransmission probability at just 5% loss. This experiment tests whether that finding holds with the now-standardized NIST algorithms (ML-KEM-768 / FIPS 203) that were not available in 2020.

## Algorithms Tested

| Algorithm | Type | Public Key Size | In Paquin et al. |
|---|---|---|---|
| X25519 | Classical baseline | 32 bytes | Yes |
| ML-KEM-768 (NIST FIPS 203) | Lattice PQC | 1,184 bytes | No — new contribution |
| FrodoKEM-640-AES | Lattice PQC (unstructured) | 9,616 bytes | Yes |
| BIKE-L1 | Code-based PQC | 1,541 bytes | No — new contribution |
| X25519+ML-KEM-768 | Hybrid | Combined | No — new contribution |

## Experimental Setup

- **OS:** Ubuntu (WSL2 on Windows)
- **OpenSSL:** 3.3.2 (compiled from source)
- **liboqs:** latest (compiled from source)
- **oqs-provider:** latest
- **Network emulation:** Linux `tc` / NetEm on loopback interface
- **Fixed RTT:** 100ms (representing intercontinental connection)
- **Packet loss rates:** 0%, 1%, 3%, 5%, 10%
- **Samples:** 200 TLS handshakes per algorithm per loss rate
- **Measurement:** Handshake completion time via `openssl s_server` / `s_client`

## Key Findings

### Median Handshake Time (ms)

| Algorithm | 0% | 1% | 3% | 5% | 10% |
|---|---|---|---|---|---|
| X25519 (classical) | 324.0 | 321.0 | 323.0 | 325.0 | 510.0 |
| ML-KEM-768 | 323.0 | 322.0 | 324.0 | 327.0 | 554.0 |
| FrodoKEM-640-AES | 325.0 | 322.0 | 327.0 | 328.0 | 458.5 |
| BIKE-L1 | 218.0 | 217.0 | 220.0 | 221.0 | 222.0 |
| X25519+ML-KEM-768 (hybrid) | 322.0 | 326.0 | 326.0 | 327.0 | 573.5 |

### 95th Percentile Handshake Time (ms)

| Algorithm | 0% | 1% | 3% | 5% | 10% |
|---|---|---|---|---|---|
| X25519 (classical) | 326.0 | 451.1 | 1341.1 | 1334.0 | 1746.4 |
| ML-KEM-768 | 327.0 | 643.0 | 1321.0 | 1340.1 | 2467.6 |
| FrodoKEM-640-AES | 327.0 | 455.0 | 1337.1 | 1426.2 | 1697.6 |
| BIKE-L1 | 221.0 | 616.1 | 621.0 | 1226.0 | 1456.6 |
| X25519+ML-KEM-768 (hybrid) | 327.0 | 499.9 | 1331.1 | 1339.1 | 1876.9 |

### Notable Findings

- **ML-KEM-768 matches classical X25519** at the median up to 5% packet loss, confirming it is a practical drop-in replacement for real-world deployment.
- **BIKE-L1 is remarkably resilient** — stable at ~220ms even at 10% loss, roughly 100ms faster than all other algorithms. This is consistent with Oussama's finding that BIKE-L1 outperforms X25519 by 32% under intercontinental conditions.
- **FrodoKEM's P95 degrades early** (1337ms at 3% loss), confirming Paquin et al.'s fragmentation hypothesis.
- **Hybrid X25519+ML-KEM-768 adds minimal overhead** over pure ML-KEM-768 at the median, supporting hybrid deployment viability during the transition period.

## Repository Structure
pqc-tls-packetloss-benchmark/
├── results_packetloss/
│   ├── x25519_loss0.csv          # 200 handshake times per file
│   ├── x25519_loss1.csv
│   ├── ...
│   ├── frodo640aes_loss10.csv
│   └── X25519MLKEM768_loss10.csv
├── graphs_packetloss/
│   ├── median_vs_packetloss.png
│   └── p95_vs_packetloss.png
├── benchmark_packetloss.sh       # Main benchmark script
├── benchmark_hybrid.sh           # Hybrid algorithm benchmark
├── analyze_packetloss.py         # Analysis and graph generation
└── README.md

## How to Reproduce

### 1. Install dependencies

```bash
sudo apt-get install -y build-essential cmake ninja-build git libssl-dev python3-pip iproute2 bc
pip install matplotlib numpy scipy --break-system-packages
```

### 2. Build liboqs

```bash
git clone https://github.com/open-quantum-safe/liboqs.git
cd liboqs && mkdir build && cd build
cmake -GNinja -DCMAKE_INSTALL_PREFIX=$HOME/pqc-tls/liboqs-install ..
ninja && ninja install
```

### 3. Build OpenSSL 3.3.2

```bash
wget https://www.openssl.org/source/openssl-3.3.2.tar.gz
tar xf openssl-3.3.2.tar.gz && cd openssl-3.3.2
./Configure --prefix=$HOME/pqc-tls/openssl-3.3
make -j$(nproc) && make install
```

### 4. Build oqs-provider

```bash
git clone https://github.com/open-quantum-safe/oqs-provider.git
cd oqs-provider && mkdir build && cd build
cmake -GNinja \
  -Dliboqs_DIR=$HOME/pqc-tls/liboqs-install/lib/cmake/liboqs \
  -DOPENSSL_ROOT_DIR=$HOME/pqc-tls/openssl-3.3 ..
ninja
mkdir -p $HOME/pqc-tls/openssl-3.3/lib64/ossl-modules
cp lib/oqsprovider.so $HOME/pqc-tls/openssl-3.3/lib64/ossl-modules/
```

### 5. Configure environment

```bash
export LD_LIBRARY_PATH=$HOME/pqc-tls/liboqs-install/lib:$HOME/pqc-tls/openssl-3.3/lib64:$LD_LIBRARY_PATH
export PATH=$HOME/pqc-tls/openssl-3.3/bin:$PATH
export OPENSSL_CONF=$HOME/pqc-tls/openssl-oqs.cnf
```

Create `$HOME/pqc-tls/openssl-oqs.cnf`:

```ini
openssl_conf = openssl_init

[openssl_init]
providers = provider_sect

[provider_sect]
default = default_sect
oqsprovider = oqsprovider_sect

[default_sect]
activate = 1

[oqsprovider_sect]
activate = 1
module = /path/to/oqsprovider.so
```

### 6. Generate certificates and run

```bash
mkdir -p $HOME/pqc-tls/certs
openssl req -x509 -newkey rsa:2048 -keyout $HOME/pqc-tls/certs/server.key \
  -out $HOME/pqc-tls/certs/server.crt -days 365 -nodes -subj "/CN=localhost"

sudo bash benchmark_packetloss.sh
sudo bash benchmark_hybrid.sh
python3 analyze_packetloss.py
```

## Course Information

- **Course:** INFO-F514 — Protocols, cryptanalysis and mathematical cryptology 2025/26
- **Institution:** Université Libre de Bruxelles (ULB)
- **Group:** L
- **Supervisor:** Prof. Christophe Petit

## References

[1] C. Paquin, D. Stebila, and G. Tamvada, "Benchmarking Post-Quantum Cryptography in TLS," PQCrypto 2020, Springer LNCS vol. 12100, pp. 72–91, 2020.

[2] National Institute of Standards and Technology, "Module-Lattice-Based Key-Encapsulation Mechanism Standard," FIPS 203, 2024.

[3] P. Schwabe, D. Stebila, and T. Wiggers, "Post-Quantum TLS Without Handshake Signatures," ACM CCS 2020, pp. 1461–1480, 2020.

[4] Open Quantum Safe Project, https://openquantumsafe.org/
