all: build simulate

build:
	if [ ! -e work ]; then vlib work; fi
	vlog -sv +incdir+../../../../../../rtl/verilog/pu/riscv/ahb3/pkg -f system.vc

simulate:
	vsim -c -do run.do work.mpsoc_dbg_testbench
