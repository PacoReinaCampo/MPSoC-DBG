@echo off
call ../../../../../../../settings64_iverilog.bat

iverilog -g2012 -o system.vvp -c system.vc -s peripheral_dbg_pu_riscv_testbench
vvp system.vvp
pause
