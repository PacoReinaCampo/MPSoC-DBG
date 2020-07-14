////////////////////////////////////////////////////////////////////////////////
//                                            __ _      _     _               //
//                                           / _(_)    | |   | |              //
//                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
//               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
//              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
//               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
//                  | |                                                       //
//                  |_|                                                       //
//                                                                            //
//                                                                            //
//              MPSoC-RISCV CPU                                               //
//              Debug on Chip Interface                                       //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/* Copyright (c) 2018-2019 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 * Author(s):
 *   Philipp Wagner <philipp.wagner@tum.de>
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module ring_router_gateway #(
  parameter BUFFER_SIZE = 4,
  parameter SUBNET_BITS = 6,
  parameter LOCAL_SUBNET = 0
)
  (
    input         clk,
    input         rst,

    input [15:0]   id,

    input dii_flit   ring_in0,
    input dii_flit   ring_in1,

    output dii_flit   ring_out0,
    output dii_flit   ring_out1,

    input  dii_flit   local_in,
    output dii_flit   local_out,

    input  dii_flit   ext_in,
    output dii_flit   ext_out,

    output ring_in0_ready,
    output ring_in1_ready,

    input ring_out0_ready,
    input ring_out1_ready,

    output local_in_ready,
    input  local_out_ready,

    output ext_in_ready,
    input  ext_out_ready
  );

  dii_flit ring_fwd0;
  dii_flit ring_fwd1;
  dii_flit ring_local0;
  dii_flit ring_local1;
  dii_flit ring_ext0;
  dii_flit ring_ext1;
  dii_flit ring_muxed;

  logic ring_fwd0_ready;
  logic ring_fwd1_ready;
  logic ring_local0_ready;
  logic ring_local1_ready;
  logic ring_ext0_ready;
  logic ring_ext1_ready;
  logic ring_muxed_ready;

  ring_router_gateway_demux u_demux0 (
    .*,
    .in_ring         ( ring_in0          ),
    .in_ring_ready   ( ring_in0_ready    ),
    .out_local       ( ring_local0       ),
    .out_local_ready ( ring_local0_ready ),
    .out_ring        ( ring_fwd0         ),
    .out_ring_ready  ( ring_fwd0_ready   ),
    .out_ext         ( ring_ext0         ),
    .out_ext_ready   ( ring_ext0_ready   )
  );

  ring_router_gateway_demux u_demux1 (
    .*,
    .in_ring         ( ring_in1          ),
    .in_ring_ready   ( ring_in1_ready    ),
    .out_local       ( ring_local1       ),
    .out_local_ready ( ring_local1_ready ),
    .out_ring        ( ring_fwd1         ),
    .out_ring_ready  ( ring_fwd1_ready   ),
    .out_ext         ( ring_ext1         ),
    .out_ext_ready   ( ring_ext1_ready   )
  );

  ring_router_mux_rr u_mux_local (
    .*,
    .in0           ( ring_local0       ),
    .in0_ready     ( ring_local0_ready ),
    .in1           ( ring_local1       ),
    .in1_ready     ( ring_local1_ready ),
    .out_mux       ( local_out         ),
    .out_mux_ready ( local_out_ready   )
  );

  ring_router_mux_rr u_mux_ext (
    .*,
    .in0           ( ring_ext0         ),
    .in0_ready     ( ring_ext0_ready   ),
    .in1           ( ring_ext1         ),
    .in1_ready     ( ring_ext1_ready   ),
    .out_mux       ( ext_out           ),
    .out_mux_ready ( ext_out_ready     )
  );

  ring_router_gateway_mux u_mux_ring0 (
    .*,
    .in_ring        ( ring_fwd0        ),
    .in_ring_ready  ( ring_fwd0_ready  ),
    .in_local       ( local_in         ),
    .in_local_ready ( local_in_ready   ),
    .in_ext         ( ext_in           ),
    .in_ext_ready   ( ext_in_ready     ),
    .out_mux        ( ring_muxed       ),
    .out_mux_ready  ( ring_muxed_ready )
  );

  dii_buffer #(
    .BUF_SIZE(BUFFER_SIZE)
  )
  u_buffer0 (
    .*,
    .packet_size       (                  ),
    .flit_in           ( ring_muxed       ),
    .flit_in_ready     ( ring_muxed_ready ),
    .flit_out          ( ring_out0        ),
    .flit_out_ready    ( ring_out0_ready  )
  );

  dii_buffer #(
    .BUF_SIZE(BUFFER_SIZE)
  )
  u_buffer1 (
    .*,
    .packet_size       (                  ),
    .flit_in           ( ring_fwd1        ),
    .flit_in_ready     ( ring_fwd1_ready  ),
    .flit_out          ( ring_out1        ),
    .flit_out_ready    ( ring_out1_ready  )
  );
endmodule
