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

module riscv_debug_interface #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter MAX_REG_SIZE = 64,

  parameter BUFFER_SIZE = 4,

  parameter CHANNELS = 2
)
  (
    input  clk,
    input  rst,

    // GLIP host connection
    input                [XLEN -1:0] glip_in_data,
    input                            glip_in_valid,
    output                           glip_in_ready,

    output               [XLEN -1:0] glip_out_data,
    output                           glip_out_valid,
    input                            glip_out_ready,

    // ring connection
    output [CHANNELS-1:0][XLEN -1:0] ring_out_data,
    output [CHANNELS-1:0]            ring_out_last,
    output [CHANNELS-1:0]            ring_out_valid,
    input  [CHANNELS-1:0]            ring_out_ready,

    input  [CHANNELS-1:0][XLEN -1:0] ring_in_data,
    input  [CHANNELS-1:0]            ring_in_last,
    input  [CHANNELS-1:0]            ring_in_valid,
    output [CHANNELS-1:0]            ring_in_ready,

    // system reset request
    output sys_rst,

    // CPU reset request
    output cpu_rst
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic               [XLEN -1:0] ring_tie_data;
  logic                           ring_tie_last;
  logic                           ring_tie_valid;
  logic                           ring_tie_ready;

  logic [CHANNELS-1:0][XLEN -1:0] dii_in_data;
  logic [CHANNELS-1:0]            dii_in_last;
  logic [CHANNELS-1:0]            dii_in_valid;
  logic [CHANNELS-1:0]            dii_in_ready;

  logic [CHANNELS-1:0][XLEN -1:0] dii_out_data;
  logic [CHANNELS-1:0]            dii_out_last;
  logic [CHANNELS-1:0]            dii_out_valid;
  logic [CHANNELS-1:0]            dii_out_ready;

  logic               [XLEN -1:0] him_debug_in_data;
  logic                           him_debug_in_last;
  logic                           him_debug_in_valid;
  logic                           him_debug_in_ready;

  logic               [XLEN -1:0] him_debug_out_data;
  logic                           him_debug_out_last;
  logic                           him_debug_out_valid;
  logic                           him_debug_out_ready;

  logic               [XLEN -1:0] scm_debug_in_data;
  logic                           scm_debug_in_last;
  logic                           scm_debug_in_valid;
  logic                           scm_debug_in_ready;

  logic               [XLEN -1:0] scm_debug_out_data;
  logic                           scm_debug_out_last;
  logic                           scm_debug_out_valid;
  logic                           scm_debug_out_ready;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign ring_tie_valid = 0;

  riscv_ring_router_gateway #(
    .XLEN (XLEN)
  )
  ring_router_gateway (
    .clk (clk),
    .rst (rst),

    // the gateway is always at local address 0
    .id(64'h0),

    .ring_in0_data  (ring_in_data  [0]),
    .ring_in0_last  (ring_in_last  [0]),
    .ring_in0_valid (ring_in_valid [0]),
    .ring_in0_ready (ring_in_ready [0]),

    .ring_in1_data  (ring_in_data  [1]),
    .ring_in1_last  (ring_in_last  [1]),
    .ring_in1_valid (ring_in_valid [1]),
    .ring_in1_ready (ring_in_ready [1]),

    .ring_out0_data  (ring_out_data  [0]),
    .ring_out0_last  (ring_out_last  [0]),
    .ring_out0_valid (ring_out_valid [0]),
    .ring_out0_ready (ring_out_ready [0]),

    .ring_out1_data  (ring_out_data  [1]),
    .ring_out1_last  (ring_out_last  [1]),
    .ring_out1_valid (ring_out_valid [1]),
    .ring_out1_ready (ring_out_ready [1]),

    // local traffic for address 0: SCM
    .local_in_data  (scm_debug_out_data),
    .local_in_last  (scm_debug_out_last),
    .local_in_valid (scm_debug_out_valid),
    .local_in_ready (scm_debug_out_ready),

    .local_out_data  (scm_debug_in_data),
    .local_out_last  (scm_debug_in_last),
    .local_out_valid (scm_debug_in_valid),
    .local_out_ready (scm_debug_in_ready),

    // traffic not belonging to LOCAL_SUBNET (sent out to the host)
    .ext_in_data  (him_debug_out_data),
    .ext_in_last  (him_debug_out_last),
    .ext_in_valid (him_debug_out_valid),
    .ext_in_ready (him_debug_out_ready),

    .ext_out_data  (him_debug_in_data),
    .ext_out_last  (him_debug_in_last),
    .ext_out_valid (him_debug_in_valid),
    .ext_out_ready (him_debug_in_ready)
  );

  // Host Interface: all traffic to foreign subnets goes through this interface
  riscv_osd_him #(
    .XLEN (XLEN),

    .BUFFER_SIZE (BUFFER_SIZE)
  )
  osd_him (
    .clk             (clk),
    .rst             (rst),

    .glip_in_data    ( glip_in_data  ),
    .glip_in_valid   ( glip_in_valid ),
    .glip_in_ready   ( glip_in_ready ),

    .glip_out_data   ( glip_out_data  ),
    .glip_out_valid  ( glip_out_valid ),
    .glip_out_ready  ( glip_out_ready ),

    .dii_out_data    (him_debug_out_data),
    .dii_out_last    (him_debug_out_last),
    .dii_out_valid   (him_debug_out_valid),
    .dii_out_ready   (him_debug_out_ready),

    .dii_in_data     (him_debug_in_data),
    .dii_in_last     (him_debug_in_last),
    .dii_in_valid    (him_debug_in_valid),
    .dii_in_ready    (him_debug_in_ready)
  );

  // Subnet Control Module
  // Manages this subnet, i.e. the on-chip OSD part
  riscv_osd_scm #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .MAX_REG_SIZE (MAX_REG_SIZE)
  )
  osd_scm (
    .clk             (clk),
    .rst             (rst),

    .id              (64'd0), // must be 0

    .debug_in_data   (scm_debug_in_data),
    .debug_in_last   (scm_debug_in_last),
    .debug_in_valid  (scm_debug_in_valid),
    .debug_in_ready  (scm_debug_in_ready),

    .debug_out_data  (scm_debug_out_data),
    .debug_out_last  (scm_debug_out_last),
    .debug_out_valid (scm_debug_out_valid),
    .debug_out_ready (scm_debug_out_ready),

    .sys_rst         (sys_rst),
    .cpu_rst         (cpu_rst)
  );
endmodule
