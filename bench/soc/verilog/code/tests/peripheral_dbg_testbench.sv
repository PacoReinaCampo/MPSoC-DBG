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
// Copyright (c) 2018-2019 by the author(s)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//    Javier Reina Campo <pacoreinacampo@queenfield.tech>

module peripheral_dbg_testbench;

  `include "peripheral_dbg_pu_pkg.sv"
  `include "peripheral_dbg_soc_pkg.sv"

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  localparam XLEN = 64;
  localparam CHANNELS = 2;
  localparam NODES = 8;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  logic                           HCLK;
  logic                           HRESETn;

  logic                           rst_sys;
  logic                           rst_cpu;

  // GLIP host connection
  logic [   XLEN -1:0]            glip_in_data;
  logic                           glip_in_valid;
  logic                           glip_in_ready;

  logic [   XLEN -1:0]            glip_out_data;
  logic                           glip_out_valid;
  logic                           glip_out_ready;

  logic [CHANNELS-1:0][XLEN -1:0] debug_ring_in_data;
  logic [CHANNELS-1:0]            debug_ring_in_last;
  logic [CHANNELS-1:0]            debug_ring_in_valid;
  logic [CHANNELS-1:0]            debug_ring_in_ready;

  logic [CHANNELS-1:0][XLEN -1:0] debug_ring_out_data;
  logic [CHANNELS-1:0]            debug_ring_out_last;
  logic [CHANNELS-1:0]            debug_ring_out_valid;
  logic [CHANNELS-1:0]            debug_ring_out_ready;

  logic [   XLEN -1:0]            id_map                                   [NODES];

  logic [   XLEN -1:0]            dii_in_data                              [NODES];
  logic                           dii_in_last                              [NODES];
  logic                           dii_in_valid                             [NODES];
  logic                           dii_in_ready                             [NODES];
  logic                           dii_in_ready_expand                      [NODES];

  logic [   XLEN -1:0]            dii_out_data                             [NODES];
  logic [   XLEN -1:0]            dii_out_data_expand                      [NODES];
  logic                           dii_out_last                             [NODES];
  logic                           dii_out_last_expand                      [NODES];
  logic                           dii_out_valid                            [NODES];
  logic                           dii_out_valid_expand                     [NODES];
  logic                           dii_out_ready                            [NODES];

  logic [CHANNELS-1:0][XLEN -1:0] ext_in_data;
  logic [CHANNELS-1:0]            ext_in_last;
  logic [CHANNELS-1:0]            ext_in_valid;
  logic [CHANNELS-1:0]            ext_in_ready;  // extension input ports

  logic [CHANNELS-1:0][XLEN -1:0] ext_out_data;
  logic [CHANNELS-1:0]            ext_out_last;
  logic [CHANNELS-1:0]            ext_out_valid;
  logic [CHANNELS-1:0]            ext_out_ready;  // extension output ports

  //////////////////////////////////////////////////////////////////////////////
  // Module Body
  //////////////////////////////////////////////////////////////////////////////

  // DUT
  peripheral_dbg_soc_interface dbg_soc_interface (
    .clk(HCLK),
    .rst(HRESETn),

    .sys_rst(rst_sys),
    .cpu_rst(rst_cpu),

    .glip_in_data (glip_in_data),
    .glip_in_valid(glip_in_valid),
    .glip_in_ready(glip_in_ready),

    .glip_out_data (glip_out_data),
    .glip_out_valid(glip_out_valid),
    .glip_out_ready(glip_out_ready),

    .ring_out_data (debug_ring_in_data),
    .ring_out_last (debug_ring_in_last),
    .ring_out_valid(debug_ring_in_valid),
    .ring_out_ready(debug_ring_in_ready),

    .ring_in_data (debug_ring_out_data),
    .ring_in_last (debug_ring_out_last),
    .ring_in_valid(debug_ring_out_valid),
    .ring_in_ready(debug_ring_out_ready)
  );

  peripheral_dbg_soc_debug_ring #(
    .PORTS(CHANNELS)
  ) dbg_soc_debug_ring (
    .clk(HCLK),
    .rst(HRESETn),

    .id_map(id_map),

    .dii_in_data (dii_in_data),
    .dii_in_last (dii_in_last),
    .dii_in_valid(dii_in_valid),
    .dii_in_ready(dii_in_ready),

    .dii_out_data (dii_out_data),
    .dii_out_last (dii_out_last),
    .dii_out_valid(dii_out_valid),
    .dii_out_ready(dii_out_ready)
  );

  peripheral_dbg_soc_debug_ring_expand #(
    .PORTS(CHANNELS)
  ) dbg_soc_debug_ring_expand (
    .clk(HCLK),
    .rst(HRESETn),

    .id_map(id_map),

    .dii_in_data (dii_in_data),
    .dii_in_last (dii_in_last),
    .dii_in_valid(dii_in_valid),
    .dii_in_ready(dii_in_ready_expand),

    .dii_out_data (dii_out_data_expand),
    .dii_out_last (dii_out_last_expand),
    .dii_out_valid(dii_out_valid_expand),
    .dii_out_ready(dii_out_ready),

    .ext_in_data (ext_in_data),
    .ext_in_last (ext_in_last),
    .ext_in_valid(ext_in_valid),
    .ext_in_ready(ext_in_ready),

    .ext_out_data (ext_out_data),
    .ext_out_last (ext_out_last),
    .ext_out_valid(ext_out_valid),
    .ext_out_ready(ext_out_ready)
  );
endmodule
