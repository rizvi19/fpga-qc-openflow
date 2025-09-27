#!/usr/bin/env python3
"""Run FPGA simulator and CPU reference benchmarks and collect results."""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import os
import platform
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import math
import numpy as np

REPO_ROOT = Path(__file__).resolve().parent.parent
FPGA_CORE_DIR = REPO_ROOT / "fpga_core"
CPU_REF = REPO_ROOT / "cpu_ref" / "run_cpu.py"
RESULTS_DIR = REPO_ROOT / "experiments" / "results"
LOG_DIR = RESULTS_DIR / "logs"
WAVE_DIR = RESULTS_DIR / "waves"
DEFAULT_CSV = RESULTS_DIR / "results.csv"

# Allow importing reference simulator helpers
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
try:
    from experiments.ref_sim import (
        qft_state as ref_qft_state,
        grover_state as ref_grover_state,
        fidelity as ref_fidelity,
        l2_err as ref_l2_err,
        load_fpga_csv as ref_load_fpga_csv,
        bell_state as ref_bell_state,
    )
except Exception:
    ref_qft_state = None
    ref_grover_state = None
    ref_fidelity = None
    ref_l2_err = None
    ref_load_fpga_csv = None

SUPPORTED_FPGA = {"qft2", "qft3", "qft4", "grover2", "grover3", "grover4", "bell2"}
ALL_PROGRAMS = [
    "qft2", "qft3", "qft4", "qft5", "qft6",
    "grover2", "grover3", "grover4",
    "bell2",
]
SUBSETS = {
    "qft": [p for p in ALL_PROGRAMS if p.startswith("qft")],
    "grover": [p for p in ALL_PROGRAMS if p.startswith("grover")],
    "all": ALL_PROGRAMS,
}

SIM_RE = re.compile(r"\[SIM\] prog=(?P<prog>\S+) done=(?P<done>\d+) cycles=(?P<cycles>\d+)")
CPU_RE = re.compile(r"CPU_RESULT prog=(?P<prog>\S+) ms=(?P<ms>[\d\.eE+-]*) ok=(?P<ok>[01])(\s+reason=(?P<reason>\S+))?")


class BenchError(Exception):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run FPGA/CPU quantum circuit benchmarks")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--subset", choices=sorted(SUBSETS.keys()), help="Named subset to run")
    group.add_argument("--prog", help="Single program name")
    parser.add_argument("--cpu-only", action="store_true", help="Only run CPU reference")
    parser.add_argument("--fpga-only", action="store_true", help="Only run FPGA simulation")
    parser.add_argument("--runs", type=int, default=1, help="Number of repetitions per program (min recorded)")
    parser.add_argument("--out", type=Path, default=DEFAULT_CSV, help="Output CSV path")
    parser.add_argument("--all", action="store_true", help="Shortcut for --subset all")
    parser.add_argument("--fclk-hz", type=float, default=float(os.environ.get("FCLK_HZ", 1.0e8)), help="FPGA clock in Hz for latency conversion")
    parser.add_argument("--cpu-max-qubits", type=int, default=6, help="Max CPU qubits for QFT/Grover (default 6)")
    parser.add_argument("--cpu-qubits", type=str, default="", help="Comma-separated CPU qubit list (e.g., 2,3,4). Overrides --cpu-max-qubits")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero if strict prog fidelity < 0.95")
    return parser.parse_args()


def resolve_programs(args: argparse.Namespace) -> List[str]:
    if args.prog:
        return [args.prog]
    if args.all or args.subset == "all":
        return SUBSETS["all"]
    if args.subset:
        return SUBSETS[args.subset]
    return SUBSETS["all"]


def ensure_build(skip_fpga: bool) -> None:
    if skip_fpga:
        return
    print("[bench] Building FPGA simulator...")
    proc = subprocess.run(["make", "-C", str(FPGA_CORE_DIR), "-j"], capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise BenchError("FPGA build failed")


def run_fpga_prog(prog: str, runs: int, dump_vcd: bool) -> Dict[str, Optional[float]]:
    result: Dict[str, Optional[float]] = {"fpga_cycles": None, "fpga_us": None, "status": None}
    if prog not in SUPPORTED_FPGA:
        result["status"] = "unsupported"
        return result

    best_cycles: Optional[int] = None
    log_path = LOG_DIR / f"{prog}_fpga.log"
    logs: List[str] = []
    env = os.environ.copy()
    if dump_vcd:
        env["DUMP_VCD"] = "1"
    vcd_path = FPGA_CORE_DIR / "obj_dir" / "qc_top.vcd"

    for run_idx in range(runs):
        if vcd_path.exists():
            vcd_path.unlink()
        cmd = [str(FPGA_CORE_DIR / "obj_dir" / "Vqc_top"), f"+prog={prog}"]
        proc = subprocess.run(cmd, cwd=FPGA_CORE_DIR / "obj_dir", capture_output=True, text=True, env=env)
        logs.append(f"Run {run_idx+1} command: {' '.join(cmd)}\n")
        logs.append(proc.stdout)
        logs.append(proc.stderr)
        if proc.returncode != 0:
            result["status"] = "sim_fail"
            break
        match = SIM_RE.search(proc.stdout)
        if not match or match.group("done") != "1":
            result["status"] = "sim_fail"
            break
        cycles = int(match.group("cycles"))
        # Parse optional [BENCH] line
        m2 = re.search(r"\[BENCH\]\s+fpga_cycles=(\d+)\s+fpga_us=([\d\.]+)", proc.stdout)
        if m2:
            try:
                result["fpga_us"] = float(m2.group(2))
            except Exception:
                pass
        if best_cycles is None or cycles < best_cycles:
            best_cycles = cycles
    else:
        result["status"] = "ok"

    log_path.write_text("".join(logs))
    if dump_vcd and vcd_path.exists():
        target = WAVE_DIR / f"{prog}.vcd"
        target.write_bytes(vcd_path.read_bytes())

    if best_cycles is not None:
        result["fpga_cycles"] = float(best_cycles)
    return result


def run_cpu_prog(prog: str, runs: int) -> Dict[str, Optional[float]]:
    result: Dict[str, Optional[float]] = {"cpu_ms": None, "cpu_status": None}
    if not CPU_REF.exists():
        result["cpu_status"] = "no_cpu"
        return result

    best_ms: Optional[float] = None
    log_path = LOG_DIR / f"{prog}_cpu.log"
    logs: List[str] = []

    for run_idx in range(runs):
        cmd = [str(CPU_REF), "--prog", prog]
        proc = subprocess.run(cmd, cwd=REPO_ROOT, capture_output=True, text=True)
        logs.append(f"Run {run_idx+1} command: {' '.join(cmd)}\n")
        logs.append(proc.stdout)
        logs.append(proc.stderr)
        if proc.returncode != 0:
            # Parse reason if available
            match = CPU_RE.search(proc.stdout)
            reason = None
            if match:
                reason = match.group("reason")
            result["cpu_status"] = reason or "cpu_fail"
            break
        match = CPU_RE.search(proc.stdout)
        if not match or match.group("ok") != "1":
            reason = match.group("reason") if match else None
            result["cpu_status"] = reason or "cpu_fail"
            break
        ms_str = match.group("ms")
        ms = float(ms_str) if ms_str else None
        if ms is not None and (best_ms is None or ms < best_ms):
            best_ms = ms
    else:
        result["cpu_status"] = "ok"

    log_path.write_text("".join(logs))
    if best_ms is not None:
        result["cpu_ms"] = best_ms
    return result


def combine_status(fpga_status: Optional[str], cpu_status: Optional[str], run_fpga: bool, run_cpu: bool) -> str:
    statuses = []
    if run_fpga and fpga_status:
        statuses.append(fpga_status)
    if run_cpu and cpu_status:
        statuses.append(cpu_status)
    if not statuses:
        return "ok"
    if "sim_fail" in statuses:
        return "sim_fail"
    if "cpu_fail" in statuses:
        return "cpu_fail"
    if "unsupported" in statuses:
        return "unsupported"
    if "numpy_missing" in statuses:
        return "cpu_missing"
    if "not_implemented" in statuses:
        return "no_cpu"
    if all(status == "ok" for status in statuses):
        return "ok"
    return statuses[0]


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


def prog_qubits(name: str) -> Optional[int]:
    m = re.search(r"(\d+)$", name)
    return int(m.group(1)) if m else None


def state_csv_path(prog: str, n: int) -> Path:
    return REPO_ROOT / "experiments" / "results" / "states" / f"{prog}_fpga_q{n}.csv"


def raw_hw_norm_from_csv(path: Path) -> Optional[float]:
    try:
        rows = list(csv.DictReader(path.open()))
    except Exception:
        return None
    if not rows:
        return None
    acc = 0.0
    for row in rows:
        try:
            re_v = float(row.get("re", "0") or 0.0)
            im_v = float(row.get("im", "0") or 0.0)
            acc += re_v * re_v + im_v * im_v
        except Exception:
            continue
    return math.sqrt(acc)


def compute_fidelity_for_prog(prog: str, n: int) -> Tuple[Optional[float], Optional[float], Optional[float]]:
    """Returns (fidelity, l2_err, hw_norm) or (None, None, None)."""
    if any(x is None for x in (ref_qft_state, ref_grover_state, ref_fidelity, ref_l2_err, ref_load_fpga_csv)):
        return (None, None, None)
    p = state_csv_path(prog, n)
    if not p.exists():
        return (None, None, None)
    try:
        fpga_vec = ref_load_fpga_csv(p, lsb_first=True, n=n)
        if prog.startswith("qft"):
            ideal = ref_qft_state(n)
        elif prog.startswith("grover"):
            ideal = ref_grover_state(n, marked=(1 << n) - 1)
        elif prog == "bell2":
            ideal = ref_bell_state()
        else:
            hw = raw_hw_norm_from_csv(p)
            return (None, None, hw)
        fid = ref_fidelity(fpga_vec, ideal)
        l2 = ref_l2_err(fpga_vec, ideal)
        hw = raw_hw_norm_from_csv(p)
        return (float(fid), float(l2), float(hw) if hw is not None else None)
    except Exception:
        return (None, None, None)



def write_csv(rows: List[Dict[str, Optional[str]]], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "timestamp", "git_sha", "host", "prog",
        "fpga_cycles", "fpga_us", "cpu_ms", "cpu_us", "status",
        "fidelity", "l2_err", "hw_norm",
    ]
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def git_sha() -> str:
    try:
        out = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=REPO_ROOT)
        return out.decode().strip()
    except Exception:
        return "unknown"


def main() -> int:
    args = parse_args()
    if args.cpu_only and args.fpga_only:
        print("[bench] Both --cpu-only and --fpga-only specified; nothing to do.", file=sys.stderr)
        return 1

    programs = resolve_programs(args)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    WAVE_DIR.mkdir(parents=True, exist_ok=True)

    dump_vcd = os.getenv("DUMP_VCD") is not None

    try:
        ensure_build(args.cpu_only)
    except BenchError as exc:
        print(f"[bench] {exc}", file=sys.stderr)
        return 1

    rows: List[Dict[str, Optional[str]]] = []
    failures = False
    timestamp = dt.datetime.utcnow().isoformat()
    sha = git_sha()
    host = platform.node()

    # Determine CPU qubit selection
    cpu_qubits = parse_cpu_qubit_list(args.cpu_qubits)
    if not cpu_qubits:
        cpu_qubits = list(range(2, max(2, args.cpu_max_qubits) + 1))
    print(f"[bench] CPU qubits: {cpu_qubits}")

    for prog in programs:
        print(f"[bench] Running {prog}...")
        run_fpga = not args.cpu_only
        run_cpu = not args.fpga_only
        if run_cpu and (prog.startswith("qft") or prog.startswith("grover")):
            q = prog_qubits(prog)
            if q is None or q not in cpu_qubits:
                run_cpu = False

        fpga_info = run_fpga_prog(prog, args.runs, dump_vcd) if run_fpga else {"fpga_cycles": None, "status": None}
        cpu_info = run_cpu_prog(prog, args.runs) if run_cpu else {"cpu_ms": None, "cpu_status": None}

        status = combine_status(fpga_info.get("status"), cpu_info.get("cpu_status"), run_fpga, run_cpu)
        if status in {"sim_fail", "cpu_fail"}:
            failures = True

        # Optional fidelity calculation based on dumped state
        fid = l2 = hw = None
        n = prog_qubits(prog) or 0
        if run_fpga and n > 0:
            fid, l2, hw = compute_fidelity_for_prog(prog, n)

        # Strict programs
        if prog in {"qft2", "qft4", "grover2", "bell2"} and fid is not None and fid < 0.95:
            status = "fail"
            if args.strict:
                failures = True

        row = {
            "timestamp": timestamp,
            "git_sha": sha,
            "host": host,
            "prog": prog,
            "fpga_cycles": str(fpga_info.get("fpga_cycles") or ""),
            "fpga_us": str(fpga_info.get("fpga_us") or (float(fpga_info.get("fpga_cycles")) * 1e6 / args.fclk_hz if fpga_info.get("fpga_cycles") else "")),
            "cpu_ms": str(cpu_info.get("cpu_ms") or ""),
            "cpu_us": str((cpu_info.get("cpu_ms") or 0) and (float(cpu_info.get("cpu_ms")) * 1000.0) or ""),
            "status": status,
            "fidelity": ("nan" if fid is None else f"{fid:.6f}"),
            "l2_err": ("nan" if l2 is None else f"{l2:.6f}"),
            "hw_norm": ("nan" if hw is None else f"{hw:.6f}"),
        }
        rows.append(row)
        print(f"[bench] prog={prog} fpga_us={row['fpga_us']} fidelity={row['fidelity']} l2={row['l2_err']} hw_norm={row['hw_norm']}")

    write_csv(rows, args.out)
    print(f"[bench] Wrote results to {args.out}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
