SOURCE_DIR=../../../../../../..
BENCH_DIR=$(SOURCE_DIR)/bench/pu/or1k/verilog/tests/wb/sample
INCLUDE_DIR=$(SOURCE_DIR)/rtl/pu/or1k/verilog/pkg/wb

# Set V=1 when calling make to enable verbose output
# mainly for debugging purposes.
ifeq ($(V), 1)
Q=
QUIET=
else
Q ?=@
QUIET=-quiet
endif

IVERILOG_VPI_SRC = $(SOURCE_DIR)/software/or1k/sample/jtag_vpi.c

ADV_DEBUG_SRC = $(shell ls $(SOURCE_DIR)/rtl/pu/or1k/verilog/peripheral/wb/*.sv)

IVERILOG_SRC = $(BENCH_DIR)/jtag_vpi/peripheral_jtag_vpi.sv \
               $(BENCH_DIR)/jtag_vpi/peripheral_jtag_vpi_testbench.sv \
               $(BENCH_DIR)/jtag_tap/peripheral_tap_top.sv \
               $(BENCH_DIR)/ram/peripheral_ram_b3_wb.sv \
               $(ADV_DEBUG_SRC)

all: sim

build:
	@echo '##### Building ######'
	$(Q)gcc -otest_client $(SOURCE_DIR)/software/or1k/sample/test_client.c
	$(Q)iverilog-vpi $(IVERILOG_VPI_SRC) > /dev/null
	$(Q)iverilog -I$(INCLUDE_DIR) -operipheral_jtag_vpi_testbench.vvp $(IVERILOG_SRC)

sim: build
	@echo '##### Start the simulation ######'
	$(Q)vvp -n -M. -mjtag_vpi peripheral_jtag_vpi_testbench.vvp +jtag_vpi_enable=1 &
	@sleep 1
	@echo '##### Running the test client ######'
	$(Q)./test_client
	@sleep 1
clean:
	@rm -rf *.o *~ *.vpi *.vvp *.vcd test_client
