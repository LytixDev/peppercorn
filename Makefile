IVERILOG ?= iverilog
VVP ?= vvp

BUILD := build
RTL := rtl
TB := tb

# Packages (*_pkg.sv) must compile before any module that imports them,
# so list them first. Icarus reads files in order and does not resolve
# dependencies on its own.
PKGS    := $(wildcard $(RTL)/*_pkg.sv)
SOURCES := $(PKGS) $(filter-out $(PKGS),$(wildcard $(RTL)/*.sv)) $(wildcard $(TB)/*.sv)
TOP ?= core_tb

VVP_FILE := $(BUILD)/sim.vvp
VCD_FILE := $(BUILD)/wave.vcd

.PHONY: all run clean

all: run

$(BUILD):
	@mkdir -p $(BUILD)

$(VVP_FILE): $(SOURCES) | $(BUILD)
	$(IVERILOG) -g2012 -Wall -s $(TOP) -o $@ $(SOURCES)

run: $(VVP_FILE)
	$(VVP) $(VVP_FILE)

clean:
	rm -rf $(BUILD)
