all: build simulate

build:
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/pkg/msp430_pkg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/main/msp430_dbg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/omsp/msp430_dbg_i2c.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/omsp/msp430_dbg_uart.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/fuse/msp430_sync_cell.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/omsp/msp430_dbg_hwbrk.vhd
	ghdl -a --std=08 ../../../../../../../bench/pu/msp430/vhdl/test/bb/mpsoc_dbg_testbench.vhd

simulate:
	ghdl -m --std=08 mpsoc_dbg_testbench
	ghdl -r --std=08 mpsoc_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_dbg_testbench.tree

clean:
	rm -f *.cf *.tree
