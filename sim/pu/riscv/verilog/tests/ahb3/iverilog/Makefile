all: build simulate

build:
	iverilog -g2012 -o system.vvp -c system.vc -s mpsoc_dbg_testbench -I ../../../../../../../rtl/pu/riscv/verilog/ahb3/pkg

simulate:
	vvp system.vvp

clean:
	rm -rf system.vvp
