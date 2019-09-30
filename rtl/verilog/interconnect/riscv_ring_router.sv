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
//              Degub Interface                                               //
//              AMBA3 AHB-Lite Bus Interface                                  //
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
 *   Francisco Javier Reina Campo <frareicam@gmail.com>
 */

`include "riscv_dbg_pkg.sv"

module riscv_ring_router #(
  parameter XLEN = 64
)
  (
    input               clk,
    input               rst,

    input  [XLEN  -1:0] id,

    input  [XLEN  -1:0] ring_in0_data,
    input               ring_in0_last,
    input               ring_in0_valid,
    output              ring_in0_ready,

    input  [XLEN  -1:0] ring_in1_data,
    input               ring_in1_last,
    input               ring_in1_valid,
    output              ring_in1_ready,

    output [XLEN  -1:0] ring_out0_data,
    output              ring_out0_last,
    output              ring_out0_valid,
    input               ring_out0_ready,

    output [XLEN  -1:0] ring_out1_data,
    output              ring_out1_last,
    output              ring_out1_valid,
    input               ring_out1_ready,

    input  [XLEN  -1:0] local_in_data,
    input               local_in_last,
    input               local_in_valid,
    output              local_in_ready,

    output [XLEN  -1:0] local_out_data,
    output              local_out_last,
    output              local_out_valid,
    input               local_out_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [XLEN -1:0] ring_fwd0_data;
  logic             ring_fwd0_last;
  logic             ring_fwd0_valid;
  logic             ring_fwd0_ready;

  logic [XLEN -1:0] ring_fwd1_data;
  logic             ring_fwd1_last;
  logic             ring_fwd1_valid;
  logic             ring_fwd1_ready;

  logic [XLEN -1:0] ring_local0_data;
  logic             ring_local0_last;
  logic             ring_local0_valid;
  logic             ring_local0_ready;

  logic [XLEN -1:0] ring_local1_data;
  logic             ring_local1_last;
  logic             ring_local1_valid;
  logic             ring_local1_ready;

  logic [XLEN -1:0] ring_muxed_data;
  logic             ring_muxed_last;
  logic             ring_muxed_valid;
  logic             ring_muxed_ready;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  riscv_ring_router_demux #(
    .XLEN (XLEN)
  )
  u_demux0 (
    .clk             (clk),
    .rst             (rst),

    .id              (id),

    .in_ring_data    ( ring_in0_data     ),
    .in_ring_last    ( ring_in0_last     ),
    .in_ring_valid   ( ring_in0_valid    ),
    .in_ring_ready   ( ring_in0_ready    ),

    .out_local_data  ( ring_local0_data  ),
    .out_local_last  ( ring_local0_last  ),
    .out_local_valid ( ring_local0_valid ),
    .out_local_ready ( ring_local0_ready ),

    .out_ring_data   ( ring_fwd0_data    ),
    .out_ring_last   ( ring_fwd0_last    ),
    .out_ring_valid  ( ring_fwd0_valid   ),
    .out_ring_ready  ( ring_fwd0_ready   )
  );

  riscv_ring_router_demux #(
    .XLEN (XLEN)
  )
  u_demux1 (
    .clk             (clk),
    .rst             (rst),

    .id              (id),

    .in_ring_data    ( ring_in1_data     ),
    .in_ring_last    ( ring_in1_last     ),
    .in_ring_valid   ( ring_in1_valid    ),
    .in_ring_ready   ( ring_in1_ready    ),

    .out_local_data  ( ring_local1_data  ),
    .out_local_last  ( ring_local1_last  ),
    .out_local_valid ( ring_local1_valid ),
    .out_local_ready ( ring_local1_ready ),

    .out_ring_data   ( ring_fwd1_data    ),
    .out_ring_last   ( ring_fwd1_last    ),
    .out_ring_valid  ( ring_fwd1_valid   ),
    .out_ring_ready  ( ring_fwd1_ready   )
  );

  riscv_ring_router_mux_rr #(
    .XLEN (XLEN)
  )
  u_mux_local (
    .clk           (clk),
    .rst           (rst),

    .in0_data      ( ring_local0_data  ),
    .in0_last      ( ring_local0_last  ),
    .in0_valid     ( ring_local0_valid ),
    .in0_ready     ( ring_local0_ready ),

    .in1_data      ( ring_local1_data  ),
    .in1_last      ( ring_local1_last  ),
    .in1_valid     ( ring_local1_valid ),
    .in1_ready     ( ring_local1_ready ),

    .out_mux_data  ( local_out_data    ),
    .out_mux_last  ( local_out_last    ),
    .out_mux_valid ( local_out_valid   ),
    .out_mux_ready ( local_out_ready   )
  );

  riscv_ring_router_mux #(
    .XLEN (XLEN)
  )
  u_mux_ring0 (
    .clk            (clk),
    .rst            (rst),

    .in_ring_data   ( ring_fwd0_data   ),
    .in_ring_last   ( ring_fwd0_last   ),
    .in_ring_valid  ( ring_fwd0_valid  ),
    .in_ring_ready  ( ring_fwd0_ready  ),

    .in_local_data  ( local_in_data    ),
    .in_local_last  ( local_in_last    ),
    .in_local_valid ( local_in_valid   ),
    .in_local_ready ( local_in_ready   ),

    .out_mux_data   ( ring_muxed_data  ),
    .out_mux_last   ( ring_muxed_last  ),
    .out_mux_valid  ( ring_muxed_valid ),
    .out_mux_ready  ( ring_muxed_ready )
  );

  riscv_dii_buffer #(
    .XLEN        (XLEN),
    .BUFFER_SIZE (`BUFFER_SIZE)
  )
  u_buffer0 (
    .clk               (clk),
    .rst               (rst),

    .packet_size       (                  ),

    .flit_in_data      ( ring_muxed_data  ),
    .flit_in_last      ( ring_muxed_last  ),
    .flit_in_valid     ( ring_muxed_valid ),
    .flit_in_ready     ( ring_muxed_ready ),

    .flit_out_data     ( ring_out0_data   ),
    .flit_out_last     ( ring_out0_last   ),
    .flit_out_valid    ( ring_out0_valid  ),
    .flit_out_ready    ( ring_out0_ready  )
  );

  riscv_dii_buffer #(
    .XLEN        (XLEN),
    .BUFFER_SIZE (`BUFFER_SIZE)
  )
  u_buffer1 (
    .clk               (clk),
    .rst               (rst),

    .packet_size       (                  ),

    .flit_in_data      ( ring_fwd1_data   ),
    .flit_in_last      ( ring_fwd1_last   ),
    .flit_in_valid     ( ring_fwd1_valid  ),
    .flit_in_ready     ( ring_fwd1_ready  ),

    .flit_out_data     ( ring_out1_data   ),
    .flit_out_last     ( ring_out1_last   ),
    .flit_out_valid    ( ring_out1_valid  ),
    .flit_out_ready    ( ring_out1_ready  )
  );
endmodule
