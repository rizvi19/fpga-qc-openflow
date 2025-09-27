#!/usr/bin/env python3
"""Plot benchmarking results produced by run_bench.py."""
from __future__ import annotations

import csv
import sys
from collections import defaultdict
from pathlib import Path
from typing import Dict, List, Tuple

try:
    import matplotlib.pyplot as plt
except ModuleNotFoundError as exc:  # pragma: no cover - optional dependency
    print(f"[plots] matplotlib is required: {exc}", file=sys.stderr)
    sys.exit(1)

REPO_ROOT = Path(__file__).resolve().parent.parent
RESULTS_CSV = REPO_ROOT / "experiments" / "results" / "results.csv"
PLOT_QFT = REPO_ROOT / "experiments" / "results" / "plot_qft_scaling.png"
PLOT_GROVER = REPO_ROOT / "experiments" / "results" / "plot_grover_scaling.png"


def read_results(csv_path: Path) -> List[Dict[str, str]]:
    if not csv_path.exists():
        raise FileNotFoundError(f"Results file not found: {csv_path}")
    with csv_path.open() as f:
        reader = csv.DictReader(f)
        return list(reader)


def extract_family(rows: List[Dict[str, str]], prefix: str) -> Tuple[Dict[int, float], Dict[int, float], int, int]:
    fpga: Dict[int, float] = {}
    cpu: Dict[int, float] = {}
    skipped_fpga = 0
    skipped_cpu = 0
    for row in rows:
        prog = row.get("prog", "")
        if not prog.startswith(prefix):
            continue
        try:
            qubits = int(''.join(filter(str.isdigit, prog)))
        except ValueError:
            continue
        status = row.get("status", "")
        if status not in {"ok", "no_cpu", "unsupported"}:
            skipped_fpga += 1
            skipped_cpu += 1
            continue
        fpga_val = row.get("fpga_cycles", "")
        if fpga_val:
            fpga[qubits] = float(fpga_val)
        else:
            skipped_fpga += 1
        cpu_val = row.get("cpu_ms", "")
        if cpu_val:
            cpu[qubits] = float(cpu_val)
        else:
            skipped_cpu += 1
    return fpga, cpu, skipped_fpga, skipped_cpu


def plot_scaling(fpga: Dict[int, float], cpu: Dict[int, float], skipped_fpga: int, skipped_cpu: int,
                 title: str, xlabel: str, fpga_label: str, cpu_label: str, output: Path) -> None:
    if not fpga and not cpu:
        print(f"[plots] No data available for {title}, skipping plot.")
        return

    qubits = sorted(set(fpga.keys()) | set(cpu.keys()))
    fig, ax1 = plt.subplots(figsize=(6, 4))
    ax1.set_title(title)
    ax1.set_xlabel(xlabel)
    ax1.set_ylabel("FPGA cycles")

    if fpga:
        ax1.plot([q for q in qubits if q in fpga], [fpga[q] for q in qubits if q in fpga], marker='o', label=f"{fpga_label}")
    ax2 = ax1.twinx()
    ax2.set_ylabel("CPU time (ms)")
    if cpu:
        ax2.plot([q for q in qubits if q in cpu], [cpu[q] for q in qubits if q in cpu], marker='s', color='tab:orange', label=f"{cpu_label}")

    lines, labels = [], []
    for axis in (ax1, ax2):
        line, label = axis.get_legend_handles_labels()
        lines.extend(line)
        labels.extend(label)
    if skipped_fpga or skipped_cpu:
        labels.append(f"Skipped points: FPGA={skipped_fpga}, CPU={skipped_cpu}")
        lines.append(plt.Line2D([], [], linestyle=''))
    if lines:
        ax1.legend(lines, labels, loc='upper left')

    ax1.grid(True, linestyle='--', alpha=0.3)
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(output)
    plt.close(fig)
    print(f"[plots] Wrote {output}")


def main() -> int:
    try:
        rows = read_results(RESULTS_CSV)
    except FileNotFoundError as exc:
        print(f"[plots] {exc}", file=sys.stderr)
        return 1

    qft_fpga, qft_cpu, qft_skip_fpga, qft_skip_cpu = extract_family(rows, "qft")
    grover_fpga, grover_cpu, grover_skip_fpga, grover_skip_cpu = extract_family(rows, "grover")

    plot_scaling(qft_fpga, qft_cpu, qft_skip_fpga, qft_skip_cpu,
                 "QFT scaling", "Qubits", "FPGA cycles", "CPU ms", PLOT_QFT)
    plot_scaling(grover_fpga, grover_cpu, grover_skip_fpga, grover_skip_cpu,
                 "Grover scaling", "Qubits", "FPGA cycles", "CPU ms", PLOT_GROVER)
    return 0


if __name__ == "__main__":
    sys.exit(main())
