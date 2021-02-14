@echo off
call ../../../../../../../settings64_verilator.bat

verilator -Wno-lint -Wno-COMBDLY --cc -f system.vc --top-module mpsoc_dbg_testbench
pause
