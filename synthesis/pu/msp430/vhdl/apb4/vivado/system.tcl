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

read_vhdl -vhdl2008 ../../../../../../rtl/pu/msp430/vhdl/code/pkg/apb4/peripheral_dbg_pu_msp430_pkg.vhd

read_vhdl -vhdl2008 ../../../../../../rtl/pu/msp430/vhdl/code/peripheral/apb4/main/peripheral_dbg_pu_msp430.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/msp430/vhdl/code/peripheral/apb4/omsp/peripheral_dbg_pu_msp430_i2c.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/msp430/vhdl/code/peripheral/apb4/omsp/peripheral_dbg_pu_msp430_uart.vhd
read_vhdl -vhdl2008 ../../../../../../rtl/pu/msp430/vhdl/code/peripheral/apb4/omsp/peripheral_dbg_pu_msp430_hwbrk.vhd

read_vhdl -vhdl2008 peripheral_dbg_synthesis.vhd

read_xdc system.xdc

synth_design -part xc7z020-clg484-1 -top peripheral_dbg_synthesis

opt_design
place_design
route_design

report_utilization
report_timing

write_bitstream -force system.bit
