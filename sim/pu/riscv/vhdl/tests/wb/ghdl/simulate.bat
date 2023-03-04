:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::                                            __ _      _     _                  ::
::                                           / _(_)    | |   | |                 ::
::                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |                 ::
::               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |                 ::
::              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |                 ::
::               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|                 ::
::                  | |                                                          ::
::                  |_|                                                          ::
::                                                                               ::
::                                                                               ::
::              Peripheral for MPSoC                                             ::
::              Multi-Processor System on Chip                                   ::
::                                                                               ::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
::                                                                               ::
:: Copyright (c) 2015-2016 by the author(s)                                      ::
::                                                                               ::
:: Permission is hereby granted, free of charge, to any person obtaining a copy  ::
:: of this software and associated documentation files (the "Software"), to deal ::
:: in the Software without restriction, including without limitation the rights  ::
:: to use, copy, modify, merge, publish, distribute, sublicense, and/or sell     ::
:: copies of the Software, and to permit persons to whom the Software is         ::
:: furnished to do so, subject to the following conditions:                      ::
::                                                                               ::
:: The above copyright notice and this permission notice shall be included in    ::
:: all copies or substantial portions of the Software.                           ::
::                                                                               ::
:: THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR    ::
:: IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,      ::
:: FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE   ::
:: AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER        ::
:: LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, ::
:: OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN     ::
:: THE SOFTWARE.                                                                 ::
::                                                                               ::
:: ============================================================================= ::
:: Author(s):                                                                    ::
::   Paco Reina Campo <pacoreinacampo@queenfield.tech>                           ::
::                                                                               ::
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

@echo off
call ../../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/pkg/core/peripheral_dbg_pu_riscv_pkg.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_jsp_biu_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_jsp_module_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_top_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_biu_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/peripheral/wb/peripheral_dbg_pu_riscv_module_wb.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_bus_module_core.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_bytefifo.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_crc32.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_jsp_module_core.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_biu.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_module.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_status_reg.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_syncflop.vhd
ghdl -a --std=08 ../../../../../../../rtl/pu/riscv/vhdl/core/peripheral_dbg_pu_riscv_syncreg.vhd
ghdl -a --std=08 ../../../../../../../bench/pu/riscv/vhdl/tests/wb/peripheral_dbg_testbench.vhd

ghdl -m --std=08 peripheral_dbg_testbench
ghdl -r --std=08 peripheral_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dbg_testbench.tree
pause
