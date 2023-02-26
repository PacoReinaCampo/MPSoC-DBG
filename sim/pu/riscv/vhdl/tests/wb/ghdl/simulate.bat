@echo off
call ../../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../../rtl/soc/vhdl/pkg/peripheral_dbg_pu_riscv_pkg.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_jsp_biu_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_jsp_module_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_top_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_biu_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_module_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_bus_module_core.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_bytefifo.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_crc32.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_jsp_module_core.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_biu.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_module.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_status_reg.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_syncflop.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_syncreg.vhd
ghdl -a --std=08 ../../../../../../../bench/pu/riscv/vhdl/tests/wb/peripheral_dbg_pu_riscv_testbench.vhd

ghdl -m --std=08 peripheral_dbg_pu_riscv_testbench
ghdl -r --std=08 peripheral_dbg_pu_riscv_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dbg_pu_riscv_testbench.tree
pause
