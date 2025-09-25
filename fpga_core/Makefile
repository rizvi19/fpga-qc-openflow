# =====================
# Verilator build setup
# =====================
VERILATOR ?= verilator
TOP       ?= qc_top

RTL_DIR   := rtl
TB_DIR    := tb
BUILD_DIR := obj_dir

RTL_SRCS  := $(wildcard $(RTL_DIR)/*.sv)
TB_SRC    := $(TB_DIR)/qc_tb.cpp

CFLAGS    := -O3 -std=c++17
VFLAGS    := -Wall --trace -O3 --cc --exe --build \
             -Wno-UNOPTFLAT -Wno-fatal

.PHONY: all sim_smoke waves clean

all: sim_smoke

sim_smoke: $(BUILD_DIR)/V$(TOP)
	@echo "[Run] Smoke simulation..."
	./$(BUILD_DIR)/V$(TOP)

$(BUILD_DIR)/V$(TOP): $(RTL_SRCS) $(TB_SRC)
	$(VERILATOR) $(VFLAGS) -CFLAGS "$(CFLAGS)" -o V$(TOP) $(TB_SRC) $(RTL_SRCS) --top-module $(TOP)

waves:
	gtkwave $(BUILD_DIR)/$(TOP).vcd &

clean:
	rm -rf $(BUILD_DIR) *.vcd
