
#!/usr/bin/env bash
set -euo pipefail

echo "[1/3] Updating apt and installing tools..."
sudo apt update
sudo apt install -y build-essential git cmake python3 python3-venv python3-pip \
    verilator yosys nextpnr-ecp5 nextpnr-ice40 gtkwave

echo "[2/3] Creating conda env (qcbench) if conda is available..."
if command -v conda >/dev/null 2>&1; then
  conda env create -f env/environment.yml || true
  echo "Run: conda activate qcbench"
else
  echo "Conda not found. Install Miniconda first: https://docs.conda.io/en/latest/miniconda.html"
fi

echo "[3/3] Done. See README.md for next steps."
