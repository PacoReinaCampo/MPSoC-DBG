all: build simulate

build:
	if [ ! -e work ]; then vlib work; fi
	vcom -2008 -f system.vc

simulate:
	vsim -c -do run.do work.peripheral_dbg_pu_riscv_testbench

clean:
	rm -rf work transcript
