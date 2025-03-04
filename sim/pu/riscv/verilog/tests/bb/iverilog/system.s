###################################################################################
##                                            __ _      _     _                  ##
##                                           / _(_)    | |   | |                 ##
##                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |                 ##
##               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |                 ##
##              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |                 ##
##               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|                 ##
##                  | |                                                          ##
##                  |_|                                                          ##
##                                                                               ##
##                                                                               ##
##              Peripheral for MPSoC                                             ##
##              Multi-Processor System on Chip                                   ##
##                                                                               ##
###################################################################################

###################################################################################
##                                                                               ##
## Copyright (c) 2015-2016 by the author(s)                                      ##
##                                                                               ##
## Permission is hereby granted, free of charge, to any person obtaining a copy  ##
## of this software and associated documentation files (the "Software"), to deal ##
## in the Software without restriction, including without limitation the rights  ##
## to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     ##
## copies of the Software, and to permit persons to whom the Software is         ##
## furnished to do so, subject to the following conditions:                      ##
##                                                                               ##
## The above copyright notice and this permission notice shall be included in    ##
## all copies or substantial portions of the Software.                           ##
##                                                                               ##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    ##
## IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      ##
## FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   ##
## AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        ##
## LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, ##
## OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     ##
## THE SOFTWARE.                                                                 ##
##                                                                               ##
## ============================================================================= ##
## Author(s):                                                                    ##
##   Paco Reina Campo <pacoreinacampo@queenfield.tech>                           ##
##                                                                               ##
###################################################################################

+incdir+../../../../../../../rtl/pu/riscv/verilog/code/pkg/core

../../../../../../../rtl/pu/riscv/verilog/code/peripheral/bb/peripheral_dbg_pu_riscv_bb_bb.sv
../../../../../../../rtl/pu/riscv/verilog/code/peripheral/bb/peripheral_dbg_pu_riscv_module_bb.sv
../../../../../../../rtl/pu/riscv/verilog/code/peripheral/bb/peripheral_dbg_pu_riscv_jsp_bb_bb.sv
../../../../../../../rtl/pu/riscv/verilog/code/peripheral/bb/peripheral_dbg_pu_riscv_jsp_module_bb.sv
../../../../../../../rtl/pu/riscv/verilog/code/peripheral/bb/peripheral_dbg_pu_riscv_top_bb.sv

../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_bus_module_core.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_bytefifo.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_crc32.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_jsp_module_core.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_bb.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_module.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_status_reg.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_syncflop.sv
../../../../../../../rtl/pu/riscv/verilog/code/core/peripheral_dbg_pu_riscv_syncreg.sv

../../../../../../../verification/tasks/pu/riscv/verilog/code/tests/bb/peripheral_dbg_testbench.sv
