all: build simulate

build:
	iverilog -g2012 -o system.vvp -c system.vc -s mpsoc_dbg_testbench -I ../../../../../../../rtl/pu/msp430/verilog/bb/pkg

simulate:
	vvp system.vvp

clean:
	rm -rf system.vvp
