vlib work
vlog -sv +incdir+../../../../../../../rtl/pu/riscv/verilog/ahb3/pkg -f system.vc
vsim -c -do run.do work.mpsoc_dbg_testbench
