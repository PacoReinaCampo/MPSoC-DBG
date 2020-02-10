all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vlog -sv +incdir+../../../../rtl/verilog/pkg -f dbg.vc
	vsim -c -do run.do work.mpsoc_dbg_testbench
