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

module riscv_debug_ring #(
  parameter XLEN     = 64,
  parameter CHANNELS = 2,
  parameter NODES    = 1
)
  (
    input              clk,
    input              rst,

    input  [NODES-1:0][XLEN -1:0] id_map,

    input  [NODES-1:0][XLEN -1:0] dii_in_data,
    input  [NODES-1:0]            dii_in_last,
    input  [NODES-1:0]            dii_in_valid,
    output [NODES-1:0]            dii_in_ready,

    output [NODES-1:0][XLEN -1:0] dii_out_data,
    output [NODES-1:0]            dii_out_last,
    output [NODES-1:0]            dii_out_valid,
    input  [NODES-1:0]            dii_out_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [CHANNELS-1:0][XLEN -1:0] ext_port_data  [CHANNELS];
  logic [CHANNELS-1:0]            ext_port_last  [CHANNELS];
  logic [CHANNELS-1:0]            ext_port_valid [CHANNELS];
  logic [CHANNELS-1:0]            ext_port_ready [CHANNELS];

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  riscv_debug_ring_expand #(
    .XLEN     (XLEN),
    .CHANNELS (CHANNELS),
    .NODES    (NODES)
  )
  debug_ring_expand (
    .clk (clk),
    .rst (rst),

    .id_map (id_map),

    .dii_in_data  (dii_in_data),
    .dii_in_last  (dii_in_last),
    .dii_in_valid (dii_in_valid),
    .dii_in_ready (dii_in_ready),

    .dii_out_data  (dii_out_data),
    .dii_out_last  (dii_out_last),
    .dii_out_valid (dii_out_valid),
    .dii_out_ready (dii_out_ready),

    .ext_in_data   ( ext_port_data  [0] ),
    .ext_in_last   ( ext_port_last  [0] ),
    .ext_in_valid  ( ext_port_valid [0] ),
    .ext_in_ready  ( ext_port_ready [0] ),

    .ext_out_data  ( ext_port_data  [1] ),
    .ext_out_last  ( ext_port_last  [1] ),
    .ext_out_valid ( ext_port_valid [1] ),
    .ext_out_ready ( ext_port_ready [1] )
  );

  // empty input for chain 0
  assign ext_port_valid[0][0] = 1'b0;

  // connect the ends of chain 0 & 1
  assign ext_port_data  [0][1] = ext_port_data  [1][0];
  assign ext_port_last  [0][1] = ext_port_last  [1][0];
  assign ext_port_valid [0][1] = ext_port_valid [1][0];
  assign ext_port_ready [1][0] = ext_port_ready [0][1];

  // dump chain 1
  assign ext_port_ready[1][1] = 1'b1;
endmodule // debug_ring
