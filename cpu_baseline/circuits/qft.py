
import numpy as np

def qft_circuit(nqubits: int):
    """Return a gate list for QFT on nqubits.
    Conventions:
      - Qubit indices: 0 = LSB
      - After controlled phases and H per wire, perform bit-reversal via SWAPs.
    Ops emitted as tuples:
      ('H', t)
      ('CPHASE', control, target, theta)
      ('SWAP', q1, q2)
    """
    ops = []
    for j in range(nqubits):
        # Hadamard on qubit j
        ops.append(('H', j))
        # Controlled phases from higher qubits k>j onto j
        for k in range(j + 1, nqubits):
            theta = np.pi / (2 ** (k - j))  # R_{k-j+1} angle = pi / 2^{k-j}
            ops.append(('CPHASE', k, j, float(theta)))
    # Final bit-reversal
    for j in range(nqubits // 2):
        ops.append(('SWAP', j, nqubits - 1 - j))
    return ops
