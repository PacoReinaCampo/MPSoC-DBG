all: build

build:
	@if [ ! -e work ]; then vlib work; fi
	@vcom -2008 -f dbg.vc
	vsim -c -do run.do work.mpsoc_dbg_testbench
