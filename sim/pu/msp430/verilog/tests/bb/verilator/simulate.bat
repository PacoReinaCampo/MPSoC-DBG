@echo off
call ../../../../../../../settings64_verilator.bat

verilator -Wno-lint -Wno-COMBDLY +incdir+../../../../../../../rtl/pu/msp430/verilog/bb/pkg --cc -f system.vc --top-module mpsoc_dbg_testbench
pause
