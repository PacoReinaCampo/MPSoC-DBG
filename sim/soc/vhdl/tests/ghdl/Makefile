all: build simulate

build:
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/pkg/mpsoc_pkg.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/pkg/mpsoc_dbg_pkg.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/buffer/mpsoc_dii_buffer.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/buffer/mpsoc_osd_fifo.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/eventpacket/mpsoc_osd_event_packetization_fixedwidth.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/eventpacket/mpsoc_osd_event_packetization.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/regaccess/mpsoc_osd_regaccess_demux.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/regaccess/mpsoc_osd_regaccess_layer.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/regaccess/mpsoc_osd_regaccess.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/blocks/tracesample/mpsoc_osd_tracesample.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_debug_ring_expand.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_debug_ring.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_ring_router_demux.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_ring_router_gateway_demux.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_ring_router_gateway_mux.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_ring_router_gateway.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_ring_router_mux_rr.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_ring_router_mux.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/interconnect/mpsoc_ring_router.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/modules/ctm/mpsoc_osd_ctm_template.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/modules/ctm/mpsoc_osd_ctm.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/modules/him/mpsoc_osd_him.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/modules/scm/mpsoc_osd_scm.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/modules/stm/mpsoc_osd_stm_template.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/modules/stm/mpsoc_osd_stm.vhd
	ghdl -a --std=08 ../../../../../rtl/soc/vhdl/mpsoc_debug_interface.vhd
	ghdl -a --std=08 ../../../../../bench/soc/vhdl/tests/mpsoc_dbg_testbench.vhd

simulate:
	ghdl -m --std=08 mpsoc_dbg_testbench
	ghdl -r --std=08 mpsoc_dbg_testbench --ieee-asserts=disable-at-0 --disp-tree=inst > mpsoc_dbg_testbench.tree

clean:
	rm -f *.cf *.tree
