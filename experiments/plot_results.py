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
PLOTS_DIR = REPO_ROOT / "experiments" / "results"
LEGACY_QFT = PLOTS_DIR / "legacy_scaling_qft.png"
LEGACY_GROVER = PLOTS_DIR / "legacy_scaling_grover.png"
LAT_QFT = PLOTS_DIR / "latency_scaling_qft.png"
LAT_GROVER = PLOTS_DIR / "latency_scaling_grover.png"
FID_QFT = PLOTS_DIR / "fidelity_qft.png"
FID_GROVER = PLOTS_DIR / "fidelity_grover.png"

def parse_args():
    import argparse, os
    p = argparse.ArgumentParser(description="Plot scaling from results.csv")
    p.add_argument("--csv", default=str(RESULTS_CSV), help="Path to results.csv")
    p.add_argument("--fclk-hz", type=float, default=float(os.environ.get("FCLK_HZ", 1.0e8)), help="FPGA clock in Hz if fpga_us missing")
    p.add_argument("--include-legacy", action="store_true", help="Also generate legacy cycle plots")
    p.add_argument("--cpu-max-qubits", type=int, default=6, help="Max CPU qubits to include (default 6)")
    p.add_argument("--cpu-qubits", type=str, default="", help="Comma list of CPU qubits to include; overrides --cpu-max-qubits")
    return p.parse_args()


def read_results(csv_path: Path) -> List[Dict[str, str]]:
    if not csv_path.exists():
        raise FileNotFoundError(f"Results file not found: {csv_path}")
    with csv_path.open() as f:
        reader = csv.DictReader(f)
        return list(reader)


def extract_family(rows: List[Dict[str, str]], prefix: str) -> Tuple[Dict[int, float], Dict[int, float], Dict[int, float], int, int]:
    fpga: Dict[int, float] = {}
    cpu: Dict[int, float] = {}
    fpga_us: Dict[int, float] = {}
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
        fu = row.get("fpga_us", "")
        if fu:
            try:
                fpga_us[qubits] = float(fu)
            except ValueError:
                pass
    return fpga, cpu, fpga_us, skipped_fpga, skipped_cpu


def parse_cpu_qubit_list(s: str) -> List[int]:
    if not s:
        return []
    out: List[int] = []
    for tok in s.split(','):
        tok = tok.strip()
        if not tok:
            continue
        try:
            q = int(tok)
            if q > 0:
                out.append(q)
        except ValueError:
            continue
    return sorted(set(out))


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

def plot_latency(fpga_us: Dict[int, float], cpu_ms: Dict[int, float], title: str, xlabel: str, output: Path, fclk_hz: float) -> None:
    # Convert CPU ms->us
    if not fpga_us and not cpu_ms:
        print(f"[plots] No data available for {title}, skipping plot.")
        return
    cpu_us = {q: v * 1000.0 for q, v in cpu_ms.items()}
    qubits = sorted(set(fpga_us.keys()) | set(cpu_us.keys()))
    fig, ax = plt.subplots(figsize=(6,4))
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Latency (us)")
    if fpga_us:
        ax.plot([q for q in qubits if q in fpga_us], [fpga_us[q] for q in qubits if q in fpga_us], marker='o', label='FPGA (us)')
    if cpu_us:
        ax.plot([q for q in qubits if q in cpu_us], [cpu_us[q] for q in qubits if q in cpu_us], marker='s', label='CPU (us)')
    ax.grid(True, linestyle='--', alpha=0.3)
    ax.legend(loc='upper left')
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(output)
    plt.close(fig)
    print(f"[plots] Wrote {output}")




def extract_fidelity(rows: list[dict[str, str]], prefix: str) -> dict[int, float]:
    fid: dict[int, float] = {}
    for row in rows:
        prog = row.get("prog", "")
        if not prog.startswith(prefix):
            continue
        try:
            qubits = int(''.join(filter(str.isdigit, prog)))
        except ValueError:
            continue
        fstr = row.get("fidelity", "")
        if not fstr or fstr.lower() == "nan":
            continue
        try:
            fval = float(fstr)
        except ValueError:
            continue
        fid[qubits] = fval
    return fid


def plot_fidelity(fid: dict[int, float], title: str, xlabel: str, output: Path) -> None:
    if not fid:
        print(f"[plots] No fidelity data for {title}, skipping plot.")
        return
    qubits = sorted(fid.keys())
    ys = [fid[q] for q in qubits]
    fig, ax = plt.subplots(figsize=(6,4))
    ax.set_title(title)
    ax.set_xlabel(xlabel)
    ax.set_ylabel("Fidelity")
    ax.set_ylim(0.0, 1.0)
    ax.grid(True, linestyle='--', alpha=0.3)
    ax.plot(qubits, ys, marker='o', label='FPGA fidelity')
    ax.legend(loc='lower right')
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.tight_layout()
    fig.savefig(output)
    plt.close(fig)
    print(f"[plots] Wrote {output}")

def main() -> int:
    args = parse_args()
    try:
        rows = read_results(Path(args.csv))
    except FileNotFoundError as exc:
        print(f"[plots] {exc}", file=sys.stderr)
        return 1

    qft_fpga, qft_cpu, qft_fpga_us, qft_skip_fpga, qft_skip_cpu = extract_family(rows, "qft")
    grover_fpga, grover_cpu, grover_fpga_us, grover_skip_fpga, grover_skip_cpu = extract_family(rows, "grover")

    # Apply CPU qubit selection
    sel = parse_cpu_qubit_list(args.cpu_qubits)
    if not sel:
        sel = list(range(2, max(2, args.cpu_max_qubits) + 1))
    print(f"[plots] CPU qubits: {sel}")
    qft_cpu = {q: v for q, v in qft_cpu.items() if q in sel}
    grover_cpu = {q: v for q, v in grover_cpu.items() if q in sel}

    # Latency plots (us)
    print("[plots] generating latency plots")
    plot_latency(qft_fpga_us, qft_cpu, "QFT latency", "Qubits", LAT_QFT, args.fclk_hz)
    plot_latency(grover_fpga_us, grover_cpu, "Grover latency", "Qubits", LAT_GROVER, args.fclk_hz)

    # Fidelity plots (FPGA only)
    print("[plots] generating fidelity plots")
    qft_fid = extract_fidelity(rows, "qft")
    grover_fid = extract_fidelity(rows, "grover")
    plot_fidelity(qft_fid, "QFT fidelity", "Qubits", FID_QFT)
    plot_fidelity(grover_fid, "Grover fidelity", "Qubits", FID_GROVER)

    # Optional legacy plots
    if args.include_legacy:
        print("[plots] including legacy cycle plots")
        plot_scaling(qft_fpga, qft_cpu, qft_skip_fpga, qft_skip_cpu,
                     "QFT scaling (legacy)", "Qubits", "FPGA cycles", "CPU ms", LEGACY_QFT)
        plot_scaling(grover_fpga, grover_cpu, grover_skip_fpga, grover_skip_cpu,
                     "Grover scaling (legacy)", "Qubits", "FPGA cycles", "CPU ms", LEGACY_GROVER)
    return 0


if __name__ == "__main__":
    sys.exit(main())
