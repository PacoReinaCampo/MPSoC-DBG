@echo off
call ../../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/pkg/msp430_pkg.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/main/msp430_dbg.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/omsp/msp430_dbg_i2c.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/omsp/msp430_dbg_uart.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/fuse/msp430_sync_cell.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/msp430/vhdl/bb/core/omsp/msp430_dbg_hwbrk.vhd
ghdl -a --std=08 ../../../../../../../bench/pu/msp430/vhdl/test/bb/peripheral_dbg_pu_testbench.vhd

ghdl -m --std=08 peripheral_dbg_pu_testbench
ghdl -r --std=08 peripheral_dbg_pu_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dbg_pu_testbench.tree
pause
