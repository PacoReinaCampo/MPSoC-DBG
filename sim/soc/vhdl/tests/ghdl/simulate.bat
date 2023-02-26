@echo off
call ../../../../../../settings64_ghdl.bat

ghdl -a --std=08 ../../../../../rtl/soc/vhdl/pkg/peripheral_dbg_pu_pkg.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/pkg/peripheral_dbg_soc_pkg.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/buffer/peripheral_dbg_soc_dii_buffer.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/buffer/peripheral_dbg_soc_osd_fifo.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/eventpacket/peripheral_dbg_soc_osd_event_packetization_fixedwidth.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/eventpacket/peripheral_dbg_soc_osd_event_packetization.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/regaccess/peripheral_dbg_soc_osd_regaccess_demux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/regaccess/peripheral_dbg_soc_osd_regaccess_layer.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/regaccess/peripheral_dbg_soc_osd_regaccess.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/blocks/tracesample/peripheral_dbg_soc_osd_tracesample.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_debug_ring_expand.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_debug_ring.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_ring_router_demux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_ring_router_gateway_demux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_ring_router_gateway_mux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_ring_router_gateway.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_ring_router_mux_rr.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_ring_router_mux.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/interconnect/peripheral_dbg_soc_ring_router.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/modules/ctm/peripheral_dbg_soc_osd_ctm_template.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/modules/ctm/peripheral_dbg_soc_osd_ctm.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/modules/him/peripheral_dbg_soc_osd_him.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/modules/scm/peripheral_dbg_soc_osd_scm.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/modules/stm/peripheral_dbg_soc_osd_stm_template.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/modules/stm/peripheral_dbg_soc_osd_stm.vhd
ghdl -a --std=08 ../../../../../rtl/soc/vhdl/peripheral/top/peripheral_dbg_soc_interface.vhd
ghdl -a --std=08 ../../../../../bench/soc/vhdl/tests/peripheral_dbg_testbench.vhd
ghdl -m --std=08 peripheral_dbg_testbench
ghdl -r --std=08 peripheral_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > peripheral_dbg_testbench.tree
pause
