# AHB-to-APB Bridge - simulation & lint regression flow
#
# Open-source toolchain:
#   - Icarus Verilog (iverilog / vvp) for compile + simulation
#   - Verilator (--lint-only) for static linting
#
# Common targets:
#   make          -> lint + simulate (full regression)
#   make sim      -> compile & run the self-checking testbench
#   make lint     -> Verilator lint of the synthesizable RTL
#   make wave     -> open the VCD in GTKWave (if installed)
#   make clean    -> remove build artifacts

# Synthesizable RTL (the bridge itself)
RTL := bridge_top.v AHB_Slave_Interface.v APB_Controller.v

# Simulation-only models / stimulus
SIM_SRCS := $(RTL) AHB_Master.v APB_Interface.v Bridge_Top_tb.v

BUILD    := build
SIM_BIN  := $(BUILD)/sim.out
VCD      := $(BUILD)/bridge_tb.vcd

TOP_RTL  := Bridge_Top
TOP_TB   := Bridge_Top_tb

IVERILOG ?= iverilog
VVP      ?= vvp
VERILATOR?= verilator

IVFLAGS  := -g2012 -Wall
VLFLAGS  := --lint-only -Wall

.PHONY: all sim lint wave clean

all: lint sim

$(BUILD):
	mkdir -p $(BUILD)

# Compile + run the self-checking testbench. The recipe fails if the
# testbench reports any error (it prints "TESTBENCH FAILED").
sim: | $(BUILD)
	$(IVERILOG) $(IVFLAGS) -s $(TOP_TB) -o $(SIM_BIN) $(SIM_SRCS)
	$(VVP) $(SIM_BIN) | tee $(BUILD)/sim.log
	@! grep -q "TESTBENCH FAILED" $(BUILD)/sim.log

lint:
	$(VERILATOR) $(VLFLAGS) --top-module $(TOP_RTL) bridge.vlt $(RTL)

wave: $(VCD)
	gtkwave $(VCD) &

clean:
	rm -rf $(BUILD)
