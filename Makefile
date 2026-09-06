# ============================================================
# RTL SIMULATION MAKEFILE
#
# Usage:
#       make <top_name>
#
# Example:
#       make mac_accelerator_tb
#
# Automatically uses:
#       listfile/mac_accelerator_tb.f
# ============================================================


# ------------------------------------------------------------
# Project directories
# ------------------------------------------------------------

PROJECT_DIR := $(CURDIR)

LIST_DIR   := $(PROJECT_DIR)/listfile
SIM_DIR    := $(PROJECT_DIR)/sim


# ------------------------------------------------------------
# TOP is taken from the first command-line target
#
# make mac_accelerator_tb
#      ^^^^^^^^^^^^^^^^^^
#          becomes TOP
# ------------------------------------------------------------

TOP := $(firstword $(MAKECMDGOALS))

FILELIST := $(LIST_DIR)/$(TOP).f


# ------------------------------------------------------------
# Simulation directories
# ------------------------------------------------------------

TOP_SIM_DIR := $(SIM_DIR)/$(TOP)

VCS_DIR  := $(TOP_SIM_DIR)/vcs
LOG_DIR  := $(TOP_SIM_DIR)/logs
WAVE_DIR := $(TOP_SIM_DIR)/waves

FSDB := $(WAVE_DIR)/$(TOP).fsdb


# ============================================================
# Catch arbitrary TOP name
# ============================================================

%:
	@$(MAKE) all TOP=$@


# ============================================================
# Main flow
# ============================================================

.PHONY: all

all: check directories compile run verdi


# ============================================================
# Check
# ============================================================

.PHONY: check

check:
	@if [ ! -f "$(FILELIST)" ]; then \
		echo ""; \
		echo "ERROR: Filelist not found:"; \
		echo "  $(FILELIST)"; \
		echo ""; \
		echo "Expected file:"; \
		echo "  listfile/$(TOP).f"; \
		echo ""; \
		exit 1; \
	fi

	@echo ""
	@echo "=========================================="
	@echo "          SIMULATION SETUP"
	@echo "=========================================="
	@echo "TOP      : $(TOP)"
	@echo "FILELIST : $(FILELIST)"
	@echo ""


# ============================================================
# Create directories
# ============================================================

.PHONY: directories

directories:
	@mkdir -p "$(VCS_DIR)"
	@mkdir -p "$(LOG_DIR)"
	@mkdir -p "$(WAVE_DIR)"


compile:
	@echo ""
	@echo "=========================================="
	@echo "        QUESTASIM COMPILATION"
	@echo "=========================================="

	vlib work && \
	vlog -sv -suppress 2583,13314 -f "$(FILELIST)" \
	    2>&1 | tee "$(LOG_DIR)/compile.log"

	@if [ $$? -ne 0 ]; then \
		echo ""; \
		echo "ERROR: vlog compilation failed."; \
		exit 1; \
	fi


# ============================================================
# SIMULATION
# ============================================================

.PHONY: run

run:
	@echo ""
	@echo "=========================================="
	@echo "             SIMULATION"
	@echo "=========================================="

	vsim -voptargs=+acc -suppress 8315 -c -do "run -all; quit" $(TOP) \
	    2>&1 | tee "$(LOG_DIR)/simulation.log"

	@if [ $$? -ne 0 ]; then \
		echo ""; \
		echo "ERROR: Simulation failed."; \
		exit 1; \
	fi


# ============================================================
# VERDI / VSIM GUI
# ============================================================

.PHONY: verdi

verdi:
	@echo ""
	@echo "=========================================="
	@echo "             QUESTASIM GUI"
	@echo "=========================================="

	vsim -voptargs=+acc -gui $(TOP) &


# ============================================================
# CLEAN
# ============================================================

.PHONY: clean

clean:
	@echo "Cleaning simulation directory..."
	rm -rf $(SIM_DIR)


# ============================================================
# HELP
# ============================================================

.PHONY: help

help:
	@echo ""
	@echo "Usage:"
	@echo ""
	@echo "    make <top_name>"
	@echo ""
	@echo "Example:"
	@echo ""
	@echo "    make mac_accelerator_tb"
	@echo ""