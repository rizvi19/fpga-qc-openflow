
# fpga-qc-openflow

Open-source, reproducible benchmarking of small quantum circuits on a CPU (NumPy) vs an FPGA-style HDL core (Verilator).

## Quickstart (Day 1: CPU baseline)

```bash
conda env create -f env/environment.yml
conda activate qcbench

# Run QFT (2,3,4 qubits) and Grover-2 timings
python cpu_baseline/run_cpu.py --circuit qft --nqubits 2 --repeats 200
python cpu_baseline/run_cpu.py --circuit qft --nqubits 3 --repeats 200
python cpu_baseline/run_cpu.py --circuit qft --nqubits 4 --repeats 200
python cpu_baseline/run_cpu.py --circuit grover2 --repeats 1000
```

Outputs (CSVs) land under `results/logs/` and `results/tables/`.
```

## Tool versions
Record your versions for reproducibility:
```bash
python -V
verilator --version
yosys -V
nextpnr-ecp5 --version
```
