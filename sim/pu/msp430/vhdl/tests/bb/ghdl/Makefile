all: build simulate

build:
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/pkg/bb/peripheral_dbg_pu_msp430_pkg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/peripheral/bb/main/peripheral_dbg_pu_msp430.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/peripheral/bb/omsp/peripheral_dbg_pu_msp430_i2c.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/peripheral/bb/omsp/peripheral_dbg_pu_msp430_uart.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/peripheral/bb/fuse/peripheral_dbg_pu_msp430_sync_cell.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/peripheral/bb/omsp/peripheral_dbg_pu_msp430_hwbrk.vhd
	ghdl -a --std=08 ../../../../../../../bench/pu/msp430/vhdl/test/bb/peripheral_dbg_testbench.vhd

simulate:
	ghdl -m --std=08 peripheral_dbg_testbench
	ghdl -r --std=08 peripheral_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dbg_testbench.tree

clean:
	rm -f *.cf *.tree
