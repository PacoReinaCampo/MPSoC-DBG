all: build simulate

build:
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/pkg/mpsoc_dbg_pkg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/ahb3/mpsoc_dbg_ahb3_biu.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/ahb3/mpsoc_dbg_ahb3_module.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/ahb3/mpsoc_dbg_jsp_apb_biu.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/ahb3/mpsoc_dbg_jsp_apb_module.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/ahb3/mpsoc_dbg_top_ahb3.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_bus_module_core.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_bytefifo.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_crc32.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_jsp_module_core.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_or1k_biu.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_or1k_module.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_or1k_status_reg.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_syncflop.vhd
	ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/ahb3/core/mpsoc_dbg_syncreg.vhd
	ghdl -a --std=08 ../../../../../../../bench/pu/riscv/vhdl/tests/ahb3/mpsoc_dbg_testbench.vhd

simulate:
	ghdl -m --std=08 mpsoc_dbg_testbench
	ghdl -r --std=08 mpsoc_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_dbg_testbench.tree

clean:
	rm -f *.cf *.tree
