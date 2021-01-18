all: build simulate

build:
	iverilog -g2012 -o system.vvp -c system.vc -s mpsoc_dbg_testbench -I ../../../../../../rtl/verilog/pu/riscv/ahb3/pkg

simulate:
	vvp system.vvp

clean:
	rm -rf system.vvp
