VERILATOR ?= verilator
TOP       ?= qc_top

RTL_DIR   := rtl
TB_DIR    := tb
BUILD_DIR := obj_dir

VERILATOR_ROOT ?= $(shell $(VERILATOR) --getenv VERILATOR_ROOT)

RTL := \
  $(RTL_DIR)/complex_mac.sv \
  $(RTL_DIR)/fixed_point_pkg.sv \
  $(RTL_DIR)/gate_cnot.sv \
  $(RTL_DIR)/gate_h.sv \
  $(RTL_DIR)/gate_phase.sv \
  $(RTL_DIR)/gate_xz.sv \
  $(RTL_DIR)/microcode_rom.sv \
  $(RTL_DIR)/phase_lut.sv \
  $(RTL_DIR)/qc_top.sv \
  $(RTL_DIR)/scheduler.sv \
  $(RTL_DIR)/state_mem.sv

TB  := $(TB_DIR)/qc_tb.cpp

SIM        := $(BUILD_DIR)/V$(TOP)
CFLAGS     := -O3 -std=c++17 -I$(BUILD_DIR) -I$(VERILATOR_ROOT)/include
VFLAGS     := -Wall --trace -O3 --cc --exe --build \
              -Wno-UNOPTFLAT -Wno-fatal \
              --Mdir $(BUILD_DIR)

.PHONY: all lint test \
	sim_qft2 sim_qft3 sim_qft4 \
	sim_grover2 sim_grover3 sim_grover4 \
	sim_bell2 cover waves clean synth

all: sim_qft4

$(SIM): $(RTL) $(TB)
	$(VERILATOR) $(VFLAGS) -CFLAGS "$(CFLAGS)" -o V$(TOP) $(TB) $(RTL) --top-module $(TOP)

sim_qft2: $(SIM)
	./$(SIM) +prog=qft2

sim_qft3: $(SIM)
	./$(SIM) +prog=qft3

sim_qft4: $(SIM)
	./$(SIM) +prog=qft4

sim_grover2: $(SIM)
	./$(SIM) +prog=grover2

sim_grover3: $(SIM)
	./$(SIM) +prog=grover3

sim_grover4: $(SIM)
	./$(SIM) +prog=grover4

sim_bell2: $(SIM)
	./$(SIM) +prog=bell2

lint:
	$(VERILATOR) -Wall --lint-only $(RTL) --top-module $(TOP)

test: sim_qft2 sim_qft4 sim_grover2 sim_bell2

# Optional Vivado synthesis (requires ENABLE_VIVADO=1 and vivado on PATH)
synth:
	@if [ -z "$(ENABLE_VIVADO)" ]; then \
		echo "[synth] ENABLE_VIVADO not set; skipping"; \
		exit 0; \
	fi
	@if ! command -v vivado >/dev/null 2>&1; then \
		echo "[synth] vivado not found on PATH"; \
		exit 1; \
	fi
	@echo "[synth] Launching Vivado in batch mode"
	vivado -mode batch -source synth/vivado.tcl

# Coverage
COV_DIR    := cov
COV_FLAGS  := --coverage
COV_SIM    := $(BUILD_DIR)/V$(TOP)_cov
COV_OUT_QFT2    := $(COV_DIR)/cov_qft2.dat
COV_OUT_QFT4    := $(COV_DIR)/cov_qft4.dat
COV_OUT_GROVER2 := $(COV_DIR)/cov_grover2.dat
COV_OUT_BELL2   := $(COV_DIR)/cov_bell2.dat

$(COV_SIM): $(RTL) $(TB)
	$(VERILATOR) $(VFLAGS) $(COV_FLAGS) -CFLAGS "$(CFLAGS)" -o V$(TOP)_cov $(TB) $(RTL) --top-module $(TOP)

.PHONY: cover
cover: clean $(COV_SIM)
	rm -rf $(COV_DIR)
	mkdir -p $(COV_DIR)/annot
	rm -f coverage.dat
	@echo "[cover] collecting qft2"
	./$(COV_SIM) +prog=qft2
	mv coverage.dat $(COV_OUT_QFT2)
	rm -f coverage.dat
	@echo "[cover] collecting qft4"
	./$(COV_SIM) +prog=qft4
	mv coverage.dat $(COV_OUT_QFT4)
	rm -f coverage.dat
	@echo "[cover] collecting grover2"
	./$(COV_SIM) +prog=grover2
	mv coverage.dat $(COV_OUT_GROVER2)
	rm -f coverage.dat
	@echo "[cover] collecting bell2"
	./$(COV_SIM) +prog=bell2
	mv coverage.dat $(COV_OUT_BELL2)
	verilator_coverage --write $(COV_DIR)/coverage.dat \
		$(COV_OUT_QFT2) $(COV_OUT_QFT4) $(COV_OUT_GROVER2) $(COV_OUT_BELL2)
	verilator_coverage --annotate $(COV_DIR)/annot $(COV_DIR)/coverage.dat > $(COV_DIR)/summary.txt
	@cat $(COV_DIR)/summary.txt
	@echo "Coverage artifacts written under $(COV_DIR)/"

waves:
	gtkwave $(BUILD_DIR)/qc_top.vcd &

clean:
	rm -rf $(BUILD_DIR) $(COV_DIR) *.vcd
