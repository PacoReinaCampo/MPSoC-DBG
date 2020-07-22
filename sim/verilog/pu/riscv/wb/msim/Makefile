all: build simulate

build:
	if [ ! -e work ]; then vlib work; fi
	vlog -sv +incdir+../../../../../../rtl/verilog/pu/riscv/wb/pkg -f system.vc

simulate:
	vsim -c -do run.do work.mpsoc_dbg_testbench
