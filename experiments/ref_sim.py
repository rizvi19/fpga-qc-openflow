#!/usr/bin/env python3
"""Double-precision reference statevector helpers for QFT and Grover.

Exports:
  - qft_state(n) -> complex128 state of length 2**n (QFT(|0..0>)).
  - grover_state(n, marked=None) -> complex128 after one Grover iteration
    with default marked index (2**n - 1).
  - fidelity(a, b) -> |<a|b>|^2 assuming both normalized.
  - l2_err(a, b) -> L2 norm of a-b.
  - load_fpga_csv(path, lsb_first=True, n=None) -> normalized complex128
    vector parsed from testbench CSV dumps (index,re,im).

Notes:
  - QFT(|0>) is the uniform superposition; the optional bit-reversal at
    the end has no effect for |0>, so qft_state() is simply uniform.
  - For Grover we apply: H^{\otimes n} -> oracle -> diffusion, once.
"""
from __future__ import annotations

import csv
import math
from pathlib import Path
from typing import Optional

import numpy as np


def qft_state(n: int) -> np.ndarray:
    if n < 1:
        raise ValueError("n must be >= 1")
    N = 1 << n
    # QFT(|0>) is uniform 1/sqrt(N) over all basis states
    vec = np.ones(N, dtype=np.complex128) / math.sqrt(N)
    return vec


def grover_state(n: int, marked: Optional[int] = None) -> np.ndarray:
    if n < 1:
        raise ValueError("n must be >= 1")
    N = 1 << n
    if marked is None:
        marked = N - 1
    if marked < 0 or marked >= N:
        raise ValueError("marked index out of range")

    # Start in |0>, apply H^{\otimes n} to get uniform superposition
    state = np.ones(N, dtype=np.complex128) / math.sqrt(N)
    # Oracle: phase flip on the marked state
    state[marked] *= -1.0
    # Diffusion: reflection about the mean
    mean = np.mean(state)
    state = 2.0 * mean - state
    # Normalize defensively
    norm = np.linalg.norm(state)
    if norm > 0:
        state = state / norm
    return state


def fidelity(a: np.ndarray, b: np.ndarray) -> float:
    aa = np.asarray(a, dtype=np.complex128).reshape(-1)
    bb = np.asarray(b, dtype=np.complex128).reshape(-1)
    if aa.shape != bb.shape:
        raise ValueError("statevector shapes must match for fidelity")
    ip = np.vdot(aa, bb)  # conj(a) * b
    return float(np.abs(ip) ** 2)


def l2_err(a: np.ndarray, b: np.ndarray) -> float:
    aa = np.asarray(a, dtype=np.complex128).reshape(-1)
    bb = np.asarray(b, dtype=np.complex128).reshape(-1)
    if aa.shape != bb.shape:
        raise ValueError("statevector shapes must match for L2 error")
    return float(np.linalg.norm(aa - bb))


def bell_state() -> np.ndarray:
    """Ideal (|00> + |11>)/sqrt(2) state on 2 qubits, LSB=qubit0.

    Returns complex128 vector of length 4 in computational basis order.
    """
    import numpy as _np
    v = _np.zeros(4, dtype=_np.complex128)
    v[0] = 1 / _np.sqrt(2.0)
    v[3] = 1 / _np.sqrt(2.0)
    return v


def _bit_reverse(i: int, n: int) -> int:
    r = 0
    for _ in range(n):
        r = (r << 1) | (i & 1)
        i >>= 1
    return r


def load_fpga_csv(path: str | Path, lsb_first: bool = True, n: Optional[int] = None) -> np.ndarray:
    """Load CSV dumps produced by the TB and return a normalized vector.

    CSV format: header 'index,re,im' followed by rows.
    If n is provided and lsb_first is False, indices are bit-reversed across n bits.
    """
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(p)

    rows = []
    with p.open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                idx = int(row.get("index", ""))
                re = float(row.get("re", "0"))
                im = float(row.get("im", "0"))
                rows.append((idx, re, im))
            except Exception:
                continue

    if not rows:
        return np.zeros(0, dtype=np.complex128)

    max_idx = max(idx for idx, _, _ in rows)
    if n is None:
        # Smallest n such that 2**n > max_idx
        n = max(1, int(math.ceil(math.log2(max_idx + 1))))
    N = 1 << n
    vec = np.zeros(N, dtype=np.complex128)

    for idx, re, im in rows:
        if idx < 0 or idx >= N:
            continue
        j = idx
        if not lsb_first and n is not None:
            j = _bit_reverse(idx, n)
        vec[j] = complex(re, im)

    # Normalize
    norm = np.linalg.norm(vec)
    if norm > 0:
        vec = vec / norm
    return vec


if __name__ == "__main__":
    # Tiny self-checks
    for n in (2, 3):
        q = qft_state(n)
        assert q.shape == (1 << n,)
        assert np.isclose(np.linalg.norm(q), 1.0, atol=1e-12)
        # Uniform amplitudes
        amps = np.abs(q) ** 2
        assert np.allclose(amps, np.ones_like(amps) / (1 << n), atol=1e-12)

    # Grover checks
    g2 = grover_state(2, marked=3)
    assert g2.shape == (4,)
    assert np.isclose(np.linalg.norm(g2), 1.0, atol=1e-12)
    peak_idx = int(np.argmax(np.abs(g2) ** 2))
    assert peak_idx == 3

    g3 = grover_state(3)
    assert g3.shape == (8,)
    assert np.isclose(np.linalg.norm(g3), 1.0, atol=1e-12)
    print("[ref_sim] basic self-checks passed")
