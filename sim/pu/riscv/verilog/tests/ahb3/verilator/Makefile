all: build simulate

build:
	verilator -Wno-lint -Wno-COMBDLY --cc -f system.vc --top-module mpsoc_dbg_testbench

simulate:

clean:
	rm -rf obj_dir
