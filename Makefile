
# Defaults
FCLK_HZ ?= 100e6

# Derive optional CPU selection flags for bench/plots
CPU_FLAGS :=
ifeq ($(strip $(CPU_QUBITS)),)
  ifneq ($(strip $(CPU_MAX_QUBITS)),)
    CPU_FLAGS := --cpu-max-qubits $(CPU_MAX_QUBITS)
  endif
else
  CPU_FLAGS := --cpu-qubits $(CPU_QUBITS)
endif

LEGACY_FLAG :=
ifneq ($(strip $(INCLUDE_LEGACY)),)
  LEGACY_FLAG := --include-legacy
endif

.PHONY: bench bench_qft bench_grover bench_strict plots

bench:
	@echo "[make] Bench CPU flags: $(CPU_FLAGS)"
	@echo "[make] DUMP_STATE=1"
	DUMP_STATE=1 python3 experiments/run_bench.py --all $(CPU_FLAGS)

bench_qft:
	@echo "[make] Bench CPU flags: $(CPU_FLAGS)"
	@echo "[make] DUMP_STATE=1"
	DUMP_STATE=1 python3 experiments/run_bench.py --subset qft $(CPU_FLAGS)

bench_grover:
	@echo "[make] Bench CPU flags: $(CPU_FLAGS)"
	@echo "[make] DUMP_STATE=1"
	DUMP_STATE=1 python3 experiments/run_bench.py --subset grover $(CPU_FLAGS)

plots:
	@echo "[make] Plots FCLK_HZ=$(FCLK_HZ)"
	@echo "[make] Plots CPU flags: $(CPU_FLAGS) $(LEGACY_FLAG)"
	python3 experiments/plot_results.py --fclk-hz $(FCLK_HZ) $(CPU_FLAGS) $(LEGACY_FLAG)

# Strict bench: fail on low fidelity for strict programs
bench_strict:
	@echo "[make] Bench CPU flags: $(CPU_FLAGS)"
	@echo "[make] DUMP_STATE=1"
	DUMP_STATE=1 python3 experiments/run_bench.py --all $(CPU_FLAGS) --strict
