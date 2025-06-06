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
##              MPSoC-SPRAM CPU                                                  ##
##              Synthesis Test Makefile                                          ##
##                                                                               ##
###################################################################################

###################################################################################
##                                                                               ##
## Copyright (c) 2018-2019 by the author(s)                                      ##
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
##   Francisco Javier Reina Campo <pacoreinacampo@queenfield.tech>               ##
##                                                                               ##
###################################################################################

read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/pkg/core/peripheral_dbg_pu_riscv_pkg.vhd

read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_biu.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_bus_module_core.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_bytefifo.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_crc32.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_jsp_module_core.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_module.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_status_reg.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_syncflop.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/core/peripheral_dbg_pu_riscv_syncreg.vhd

read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/peripheral/axi4/peripheral_dbg_pu_riscv_axi4_tl.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/peripheral/axi4/peripheral_dbg_pu_riscv_jsp_axi4_tl.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/peripheral/axi4/peripheral_dbg_pu_riscv_jsp_module_axi4.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/peripheral/axi4/peripheral_dbg_pu_riscv_module_axi4.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/riscv/vhdl/code/peripheral/axi4/peripheral_dbg_pu_riscv_top_axi4.vhd

read_vhdl -vhdl2008 peripheral_dbg_synthesis.vhd

read_xdc system.xdc

synth_design -part xc7z020-clg484-1 -top peripheral_dbg_synthesis

opt_design
place_design
route_design

report_utilization
report_timing

write_bitstream -force system.bit
