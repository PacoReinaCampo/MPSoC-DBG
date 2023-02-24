all: build simulate

build:
	verilator -Wno-lint -Wno-COMBDLY --cc -f system.vc --top-module peripheral_dbg_pu_testbench

simulate:

clean:
	rm -rf obj_dir
