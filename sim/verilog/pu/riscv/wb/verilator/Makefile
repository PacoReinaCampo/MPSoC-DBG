all: build simulate

build:
	verilator -Wno-lint -Wno-COMBDLY +incdir+../../../../../../rtl/verilog/pu/riscv/wb/pkg --cc -f system.vc --top-module mpsoc_dbg_testbench

simulate:

clean:
	rm -rf obj_dir
