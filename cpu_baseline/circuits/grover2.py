
import numpy as np

def grover2_once(mark='11'):
    """One iteration of Grover for 2 qubits, marking state |11⟩ by phase flip.
    Returns an initialized superposition + oracle + diffusion operator.
    Ops format:
      ('H', q), ('X', q), ('CPHASE', c, t, theta) with theta=pi for CZ, etc.
    """
    if mark != '11':
        raise NotImplementedError("This simple oracle marks |11> only.")
    ops = []
    # Initialize |++>
    ops += [('H', 0), ('H', 1)]
    # Oracle: phase flip on |11>  -> Controlled-Z between (0->1) with theta=pi
    ops += [('CPHASE', 0, 1, float(np.pi))]
    # Diffusion: H X  CZ  X H
    ops += [('H', 0), ('H', 1)]
    ops += [('X', 0), ('X', 1)]
    ops += [('CPHASE', 0, 1, float(np.pi))]
    ops += [('X', 0), ('X', 1)]
    ops += [('H', 0), ('H', 1)]
    return ops
