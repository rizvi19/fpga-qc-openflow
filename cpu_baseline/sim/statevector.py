
import numpy as np

SQRT2_INV = 1.0 / np.sqrt(2.0)

def init_state(nqubits: int, basis: int = 0, dtype=np.complex64) -> np.ndarray:
    dim = 1 << nqubits
    state = np.zeros(dim, dtype=dtype)
    state[basis] = 1.0 + 0.0j
    return state

def _bit(x: int, k: int) -> int:
    return (x >> k) & 1

def apply_h(state: np.ndarray, nqubits: int, target: int) -> None:
    dim = state.shape[0]
    step = 1 << target
    for base in range(0, dim, step << 1):
        for j in range(step):
            a = state[base + j]
            b = state[base + j + step]
            state[base + j]         = (a + b) * SQRT2_INV
            state[base + j + step]  = (a - b) * SQRT2_INV

def apply_x(state: np.ndarray, nqubits: int, target: int) -> None:
    dim = state.shape[0]
    step = 1 << target
    for base in range(0, dim, step << 1):
        for j in range(step):
            i0 = base + j
            i1 = base + j + step
            tmp = state[i0]
            state[i0] = state[i1]
            state[i1] = tmp

def apply_z(state: np.ndarray, nqubits: int, target: int) -> None:
    dim = state.shape[0]
    step = 1 << target
    for base in range(0, dim, step << 1):
        for j in range(step):
            i1 = base + j + step
            state[i1] = -state[i1]

def apply_cnot(state: np.ndarray, nqubits: int, control: int, target: int) -> None:
    if control == target:
        raise ValueError("control and target must differ")
    dim = state.shape[0]
    for idx in range(dim):
        if ((idx >> control) & 1) == 1:
            tbit = (idx >> target) & 1
            if tbit == 0:
                j = idx | (1 << target)
            else:
                j = idx & ~(1 << target)
            if j > idx:
                tmp = state[idx]
                state[idx] = state[j]
                state[j] = tmp

def apply_cphase(state: np.ndarray, nqubits: int, control: int, target: int, theta: float) -> None:
    dim = state.shape[0]
    phase = np.exp(1j * theta).astype(state.dtype)
    for idx in range(dim):
        if (((idx >> control) & 1) == 1) and (((idx >> target) & 1) == 1):
            state[idx] *= phase

def apply_swap(state: np.ndarray, nqubits: int, q1: int, q2: int) -> None:
    # Implement via 3 CNOTs (q1,q2) sequence to avoid complex index mapping
    if q1 == q2: 
        return
    apply_cnot(state, nqubits, q1, q2)
    apply_cnot(state, nqubits, q2, q1)
    apply_cnot(state, nqubits, q1, q2)

def apply_ops(state: np.ndarray, nqubits: int, ops: list) -> int:
    """Apply a list of ops. Returns gate count."""
    gates = 0
    for op in ops:
        tag = op[0].upper()
        if tag == 'H':
            _, t = op
            apply_h(state, nqubits, t); gates += 1
        elif tag == 'X':
            _, t = op
            apply_x(state, nqubits, t); gates += 1
        elif tag == 'Z':
            _, t = op
            apply_z(state, nqubits, t); gates += 1
        elif tag == 'CNOT':
            _, c, t = op
            apply_cnot(state, nqubits, c, t); gates += 1
        elif tag == 'CPHASE':
            _, c, t, theta = op
            apply_cphase(state, nqubits, c, t, theta); gates += 1
        elif tag == 'SWAP':
            _, q1, q2 = op
            apply_swap(state, nqubits, q1, q2); gates += 3  # modeled as 3 CNOTs
        else:
            raise ValueError(f"Unknown op {tag}")
    return gates
