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
call ../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/pkg/peripheral_dbg_pu_pkg.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/pkg/peripheral_dbg_soc_pkg.vhd

ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/buffer/peripheral_dbg_soc_dii_buffer.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/buffer/peripheral_dbg_soc_osd_fifo.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/eventpacket/peripheral_dbg_soc_osd_event_packetization_fixedwidth.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/eventpacket/peripheral_dbg_soc_osd_event_packetization.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/regaccess/peripheral_dbg_soc_osd_regaccess_demux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/regaccess/peripheral_dbg_soc_osd_regaccess_layer.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/regaccess/peripheral_dbg_soc_osd_regaccess.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/blocks/tracesample/peripheral_dbg_soc_osd_tracesample.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_debug_ring_expand.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_debug_ring.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_ring_router_demux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_ring_router_gateway_demux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_ring_router_gateway_mux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_ring_router_gateway.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_ring_router_mux_rr.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_ring_router_mux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/interconnect/peripheral_dbg_soc_ring_router.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/modules/ctm/peripheral_dbg_soc_osd_ctm_template.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/modules/ctm/peripheral_dbg_soc_osd_ctm.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/modules/him/peripheral_dbg_soc_osd_him.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/modules/scm/peripheral_dbg_soc_osd_scm.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/modules/stm/peripheral_dbg_soc_osd_stm_template.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/modules/stm/peripheral_dbg_soc_osd_stm.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/code/peripheral/top/peripheral_dbg_soc_interface.vhd

ghdl -a --std=08 ../../../../../bench/soc/vhdl/code/tests/peripheral_dbg_testbench.vhd

ghdl -m --std=08 peripheral_dbg_testbench
ghdl -r --std=08 peripheral_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dbg_testbench.tree
pause
