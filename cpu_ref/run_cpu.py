#!/usr/bin/env python3
"""Minimal CPU reference kernels for quantum circuits."""
from __future__ import annotations

import argparse
import math
import sys
import time
from typing import Tuple

try:
    import numpy as np
except ImportError:  # pragma: no cover - numpy should be available, but fail gracefully
    np = None


def result_line(prog: str, ms: float | None, ok: bool, reason: str | None = None) -> str:
    parts = [f"CPU_RESULT prog={prog}"]
    if ms is not None:
        parts.append(f"ms={ms:.6f}")
    else:
        parts.append("ms=")
    parts.append(f"ok={1 if ok else 0}")
    if reason:
        parts.append(f"reason={reason}")
    return " ".join(parts)


def ensure_numpy(prog: str) -> None:
    if np is None:
        line = result_line(prog, None, False, "numpy_missing")
        print(line)
        sys.exit(1)


def run_qft(qubits: int) -> None:
    ensure_numpy(f"qft{qubits}")
    size = 1 << qubits
    state = np.zeros(size, dtype=np.complex128)
    state[1 % size] = 1.0  # simple deterministic input
    omega = np.exp(2j * math.pi / size)
    norm = 1 / math.sqrt(size)
    mat = np.array([[omega ** (x * k) for x in range(size)] for k in range(size)], dtype=np.complex128)
    out = norm * mat @ state
    # Touch result to avoid optimisation
    _ = float(np.abs(out[0]))


def run_bell2() -> None:
    ensure_numpy("bell2")
    state = np.array([1, 0, 0, 0], dtype=np.complex128)
    h = (1 / math.sqrt(2)) * np.array([[1, 1], [1, -1]], dtype=np.complex128)
    kron = np.kron(h, np.eye(2))
    state = kron @ state
    cnot = np.array([[1, 0, 0, 0],
                     [0, 1, 0, 0],
                     [0, 0, 0, 1],
                     [0, 0, 1, 0]], dtype=np.complex128)
    state = cnot @ state
    _ = float(np.abs(state[0]))


def run_grover(qubits: int) -> None:
    ensure_numpy(f"grover{qubits}")
    size = 1 << qubits
    state = np.ones(size, dtype=np.complex128) / math.sqrt(size)
    target = size - 1
    # Oracle: phase flip on target
    state[target] *= -1
    # Diffusion about the mean
    mean = np.mean(state)
    state = 2 * mean - state
    _ = float(np.abs(state[target]))


def dispatch(prog: str) -> Tuple[bool, str | None]:
    if prog.startswith("qft") and prog[3:].isdigit():
        qubits = int(prog[3:])
        if qubits < 1:
            return False, "invalid_qubits"
        run_qft(qubits)
        return True, None
    if prog == "bell2":
        run_bell2()
        return True, None
    if prog.startswith("grover") and prog[6:].isdigit():
        qubits = int(prog[6:])
        if qubits < 2:
            return False, "invalid_qubits"
        run_grover(qubits)
        return True, None
    return False, "not_implemented"


def main() -> int:
    parser = argparse.ArgumentParser(description="CPU reference runner")
    parser.add_argument("--prog", required=True, help="Program name, e.g. qft4")
    args = parser.parse_args()
    prog = args.prog

    start = time.perf_counter()
    ok = False
    reason: str | None = None
    try:
        ok, reason = dispatch(prog)
    except Exception as exc:  # pragma: no cover - propagate failure
        reason = f"exception:{exc.__class__.__name__}"
        ok = False
    elapsed_ms = (time.perf_counter() - start) * 1000.0 if ok else None
    line = result_line(prog, elapsed_ms, ok, reason)
    print(line)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
