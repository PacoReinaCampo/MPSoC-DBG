###################################################################################
##                                            __ _      _     _                  ##
##                                           / _(_)    | |   | |                 ##
##                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |                 ##
##               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |                 ##
##              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |                 ##
##               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|                 ##
##                  | |                                                          ##
##                  |_|                                                          ##
##                                                                               ##
##                                                                               ##
##              Peripheral for MPSoC                                             ##
##              Multi-Processor System on Chip                                   ##
##                                                                               ##
###################################################################################

###################################################################################
##                                                                               ##
## Copyright (c) 2015-2016 by the author(s)                                      ##
##                                                                               ##
## Permission is hereby granted, free of charge, to any person obtaining a copy  ##
## of this software and associated documentation files (the "Software"), to deal ##
## in the Software without restriction, including without limitation the rights  ##
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     ##
## copies of the Software, and to permit persons to whom the Software is         ##
## furnished to do so, subject to the following conditions:                      ##
##                                                                               ##
## The above copyright notice and this permission notice shall be included in    ##
## all copies or substantial portions of the Software.                           ##
##                                                                               ##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    ##
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      ##
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   ##
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        ##
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, ##
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     ##
## THE SOFTWARE.                                                                 ##
##                                                                               ##
## ============================================================================= ##
## Author(s):                                                                    ##
##   Paco Reina Campo <pacoreinacampo@queenfield.tech>                           ##
##                                                                               ##
###################################################################################

SOURCE_DIR=../../../../../../..
BENCH_DIR=$(SOURCE_DIR)/verification/tasks/pu/or1k/verilog/code/tests/biu/sample
INCLUDE_DIR=$(SOURCE_DIR)/rtl/pu/or1k/verilog/code/pkg/biu

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

ADV_DEBUG_SRC = $(shell ls $(SOURCE_DIR)/rtl/pu/or1k/verilog/code/peripheral/biu/*.sv)

IVERILOG_SRC = $(BENCH_DIR)/jtag_vpi/jtag_vpi.sv \
               $(BENCH_DIR)/jtag_vpi/jtag_vpi_testbench.sv \
               $(BENCH_DIR)/jtag_tap/tap_top.sv \
               $(BENCH_DIR)/ram/peripheral_dbg_ram_b3_biu.sv \
               $(ADV_DEBUG_SRC)

all: sim

build:
	@echo '##### Building ######'
	$(Q)gcc -otest_client $(SOURCE_DIR)/software/or1k/sample/test_client.c
	$(Q)iverilog-vpi $(IVERILOG_VPI_SRC) > /dev/null
	$(Q)iverilog -I$(INCLUDE_DIR) -ojtag_vpi_testbench.vvp $(IVERILOG_SRC)

sim: build
	@echo '##### Start the simulation ######'
	$(Q)vvp -n -M. -mjtag_vpi jtag_vpi_testbench.vvp +jtag_vpi_enable=1 &
	@sleep 1
	@echo '##### Running the test client ######'
	$(Q)./test_client
	@sleep 1
clean:
	@rm -rf *.o *~ *.vpi *.vvp *.vcd test_client
