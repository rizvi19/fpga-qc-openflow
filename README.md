
# fpga-qc-openflow
![CI](https://github.com/shahriar-rizvi/fpga-qc-openflow/actions/workflows/sim.yml/badge.svg)

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

## FPGA core (Day 1: Verilator)

The HDL core under `fpga_core/` now builds warning-free with Verilator 5.x and GCC 11+/Clang 14+. The make targets emit self-checking simulations that fail fast on mismatches.

```bash
cd fpga_core
make clean
make sim_qft2
make sim_qft3
make sim_qft4
make sim_grover2
make sim_grover3
make sim_grover4
make sim_bell2
```

Each run prints the legacy `[SIM] prog=<name> done=1` banner followed by `[TB][PASS] <name>` when the observed state vector matches the expected quantum result. Any deviation triggers `[TB][FAIL] ...` and a non-zero exit, making the flow ready for CI.

### Lint & test shortcuts

```bash
make lint   # Verilator lint-only, warnings treated as failures
make test   # Runs all four self-checking simulations
```

### Coverage

```bash
make cover
cat cov/summary.txt
```

`make cover` rebuilds the model with `--coverage`, runs the four programs (`qft2`, `qft4`, `grover2`, `bell2`), merges the results, and emits annotated sources under `cov/annot/` plus a text summary.

### CI policy

- The GitHub Actions workflow (`.github/workflows/sim.yml`) runs lint, the full simulation regression on Ubuntu 22.04/24.04, and coverage on every push/PR.
- Verilator warnings are treated as build failures; patches must keep the design warning-free.
- Coverage summary (`cov/summary.txt`) is published as a workflow artifact, while waveforms (`*.vcd`) are only archived automatically when a job fails. Set `DUMP_VCD=1` locally when you need VCD traces.

### Benchmarks & plots

```bash
make bench     # run the full CPU/FPGA matrix
make plots     # regenerate scaling figures from the CSV
```

The bench runner writes a timestamped CSV to `experiments/results/results.csv`, individual logs under `experiments/results/logs/`, and (when `DUMP_VCD=1`) captures VCDs in `experiments/results/waves/`. The plotting helper consumes that CSV and emits `plot_qft_scaling.png` and `plot_grover_scaling.png` alongside the data.

Sample CSV row:

| timestamp | git_sha | host    | prog | fpga_cycles | cpu_ms | status |
|-----------|---------|---------|------|-------------|--------|--------|
| 2024-05-01T12:34:56 | abc1234 | localbox | qft2 | 85 | 0.27 | ok |

Benchmarks can be heavy, so the dedicated workflow (`.github/workflows/bench.yml`) is `workflow_dispatch` (manual trigger) and uploads the CSV, logs, and generated plots as artifacts.
