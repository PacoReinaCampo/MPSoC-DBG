all: build simulate

build:
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/pkg/mpsoc_dbg_pkg.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/wb/mpsoc_dbg_jsp_wb_biu.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/wb/mpsoc_dbg_jsp_wb_module.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/wb/mpsoc_dbg_top_wb.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/wb/mpsoc_dbg_wb_biu.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/wb/mpsoc_dbg_wb_module.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_bus_module_core.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_bytefifo.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_crc32.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_jsp_module_core.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_or1k_biu.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_or1k_module.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_or1k_status_reg.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_syncflop.vhd
	ghdl -a --std=08 ../../../../../../rtl/vhdl/pu/riscv/wb/core/mpsoc_dbg_syncreg.vhd
	ghdl -a --std=08 ../../../../../../bench/vhdl/pu/riscv/wb/mpsoc_dbg_testbench.vhd

simulate:
	ghdl -m --std=08 mpsoc_dbg_testbench
	ghdl -r --std=08 mpsoc_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_dbg_testbench.tree

clean:
	rm -f *.cf *.tree
