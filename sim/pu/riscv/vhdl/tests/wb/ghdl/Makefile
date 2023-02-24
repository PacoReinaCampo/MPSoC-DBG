all: build simulate

build:
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/pkg/peripheral_dbg_pu_pkg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/wb/peripheral_dbg_pu_jsp_wb_biu.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/wb/peripheral_dbg_pu_jsp_wb_module.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/wb/peripheral_dbg_pu_top_wb.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/wb/peripheral_dbg_pu_wb_biu.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/wb/peripheral_dbg_pu_wb_module.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_bus_module_core.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_bytefifo.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_crc32.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_jsp_module_core.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_or1k_biu.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_or1k_module.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_or1k_status_reg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_syncflop.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/wb/core/peripheral_dbg_pu_syncreg.vhd
	ghdl -a --std=08 ../../../../../../../bench/pu/riscv/vhdl/tests/wb/peripheral_dbg_pu_testbench.vhd

simulate:
	ghdl -m --std=08 peripheral_dbg_pu_testbench
	ghdl -r --std=08 peripheral_dbg_pu_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dbg_pu_testbench.tree

clean:
	rm -f *.cf *.tree
