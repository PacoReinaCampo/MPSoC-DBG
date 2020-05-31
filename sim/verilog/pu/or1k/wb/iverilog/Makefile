SOURCE_DIR=../../../../../..
BENCH_DIR=$(SOURCE_DIR)/bench/verilog/pu/or1k/wb/sample
INCLUDE_DIR=$(SOURCE_DIR)/rtl/verilog/pu/or1k/wb/pkg

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

ADV_DEBUG_SRC = $(shell ls $(SOURCE_DIR)/rtl/verilog/pu/or1k/wb/core/*.sv)

IVERILOG_SRC = $(BENCH_DIR)/jtag_vpi/jtag_vpi.sv \
               $(BENCH_DIR)/jtag_vpi/jtag_vpi_tb.sv \
               $(BENCH_DIR)/jtag_tap/tap_top.sv \
               $(BENCH_DIR)/ram/ram_wb_b3.sv \
               $(ADV_DEBUG_SRC)

all: build

build:
	@echo '##### Building ######'
	$(Q)gcc -otest_client $(SOURCE_DIR)/software/or1k/sample/test_client.c
	$(Q)iverilog-vpi $(IVERILOG_VPI_SRC) > /dev/null
	$(Q)iverilog -I$(INCLUDE_DIR) -ojtag_vpi_tb.vvp $(IVERILOG_SRC)

sim: build
	@echo '##### Start the simulation ######'
	$(Q)vvp -n -M. -mjtag_vpi jtag_vpi_tb.vvp +jtag_vpi_enable=1 &
	@sleep 1
	@echo '##### Running the test client ######'
	$(Q)./test_client
	@sleep 1
clean:
	@rm -rf *.o *~ *.vpi *.vvp *.vcd test_client
