all: build simulate

build:
	verilator -Wno-lint -Wno-COMBDLY +incdir+../../../../../../../rtl/pu/riscv/verilog/ahb3/pkg --cc -f system.vc --top-module mpsoc_dbg_testbench

simulate:

clean:
	rm -rf obj_dir
