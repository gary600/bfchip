SIM ?= icarus
TOPLEVEL_LANG ?= verilog

# VERILOG_SOURCES += $(BUILD_DIR)/all.v

TOPLEVEL = SimTop
MODULE = src.bf_test

SIM_BUILD = $(BUILD_DIR)/sim_build
COCOTB_RESULTS_FILE = $(BUILD_DIR)/results.xml
ifeq ($(SIM), verilator)
EXTRA_ARGS += -Wno-WIDTHEXPAND
endif

include $(shell cocotb-config --makefiles)/Makefile.sim