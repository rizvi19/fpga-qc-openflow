
import argparse, time, os, csv, numpy as np
from pathlib import Path

from sim.statevector import init_state, apply_ops
from circuits.qft import qft_circuit
from circuits.grover2 import grover2_once

def run_and_time(circuit_ops, nqubits, repeats):
    times = []
    final_state = None
    gates = 0
    for _ in range(repeats):
        st = init_state(nqubits, basis=0, dtype=np.complex64)
        t0 = time.perf_counter()
        gates = apply_ops(st, nqubits, circuit_ops)
        t1 = time.perf_counter()
        times.append((t1 - t0) * 1000.0)  # ms
        final_state = st
    arr = np.array(times, dtype=np.float64)
    return final_state, gates, float(arr.mean()), float(arr.std())

def save_csv(path, header, row):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    newfile = not os.path.exists(path)
    with open(path, 'a', newline='') as f:
        w = csv.writer(f)
        if newfile:
            w.writerow(header)
        w.writerow(row)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--circuit', choices=['qft','grover2'], required=True)
    ap.add_argument('--nqubits', type=int, default=4, help='Only used for QFT')
    ap.add_argument('--repeats', type=int, default=200)
    ap.add_argument('--outdir', type=str, default='results')
    args = ap.parse_args()

    if args.circuit == 'qft':
        ops = qft_circuit(args.nqubits)
        n = args.nqubits
        label = f'qft{n}'
    else:
        ops = grover2_once()
        n = 2
        label = 'grover2'

    final_state, gates, mean_ms, std_ms = run_and_time(ops, n, args.repeats)

    logs_path = os.path.join(args.outdir, 'logs', f'cpu_{label}.csv')
    tables_path = os.path.join(args.outdir, 'tables', 'cpu_timing.csv')

    # Save per-run summary
    save_csv(logs_path, ['circuit','nqubits','gates','repeats','mean_time_ms','std_ms'],
             [label, n, gates, args.repeats, f"{mean_ms:.6f}", f"{std_ms:.6f}"])

    # Append to global timing table
    save_csv(tables_path, ['circuit','nqubits','gates','repeats','mean_time_ms','std_ms'],
             [label, n, gates, args.repeats, f"{mean_ms:.6f}", f"{std_ms:.6f}"])

    # Save final state (for later correctness checks)
    fs_path = os.path.join(args.outdir, 'logs', f'cpu_state_{label}.npy')
    np.save(fs_path, final_state)
    print(f"[OK] {label}: gates={gates}, mean={mean_ms:.4f} ms ± {std_ms:.4f} ms")
    print(f"Saved: {logs_path} and appended {tables_path}\nFinal state -> {fs_path}")

if __name__ == '__main__':
    main()
