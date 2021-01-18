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
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module osd_regaccess_layer #(
  parameter MOD_VENDOR = 'x,
  parameter MOD_TYPE = 'x,
  parameter MOD_VERSION = 'x,
  parameter MOD_EVENT_DEST_DEFAULT = 0,
  parameter CAN_STALL = 0,
  parameter MAX_REG_SIZE = 16
)
  (
    input clk,
    input rst,

    input [15:0]  id,

    input         dii_flit debug_in,
    output        dii_flit debug_out,

    output        dii_flit module_out,
    input         dii_flit module_in,

    output logic debug_in_ready,
    input        debug_out_ready,

    input  module_out_ready,
    output module_in_ready,

    output reg                reg_request,
    output                    reg_write,
    output [            15:0] reg_addr,
    output [             1:0] reg_size,
    output [MAX_REG_SIZE-1:0] reg_wdata,
    input                     reg_ack,
    input                     reg_err,
    input  [MAX_REG_SIZE-1:0] reg_rdata,

    // DI address of the event destination
    output [15:0] event_dest,
    output        stall
  );

  dii_flit regaccess_in;
  dii_flit regaccess_out;

  logic regaccess_in_ready;
  logic regaccess_out_ready;

  osd_regaccess #(
    .MOD_VENDOR(MOD_VENDOR),
    .MOD_TYPE(MOD_TYPE),
    .MOD_EVENT_DEST_DEFAULT(MOD_EVENT_DEST_DEFAULT),
    .MOD_VERSION(MOD_VERSION),
    .CAN_STALL(CAN_STALL),
    .MAX_REG_SIZE(MAX_REG_SIZE)
  )
  u_regaccess (
    .*,
    .event_dest      (event_dest),
    .debug_in        (regaccess_in),
    .debug_in_ready  (regaccess_in_ready),
    .debug_out       (regaccess_out),
    .debug_out_ready (regaccess_out_ready)
  );

  // Ingress path demux
  osd_regaccess_demux u_demux (
    .*,
    .in (debug_in),
    .in_ready         (debug_in_ready),
    .out_reg          (regaccess_in),
    .out_reg_ready    (regaccess_in_ready),
    .out_bypass       (module_out),
    .out_bypass_ready (module_out_ready)
  );

  // Egress path mux
  ring_router_mux u_mux (
    .*,
    .in_local       (module_in),
    .in_local_ready (module_in_ready),
    .in_ring        (regaccess_out),
    .in_ring_ready  (regaccess_out_ready),
    .out_mux        (debug_out),
    .out_mux_ready  (debug_out_ready)
  );
endmodule
