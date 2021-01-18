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
import opensocdebug::mor1kx_trace_exec;

module osd_ctm_mor1kx #(
  parameter MAX_PKT_LEN = 'hx
)
  (
    input                        clk,
    input                        rst,

    input                 [15:0] id,

    input  dii_flit              debug_in,
    output dii_flit              debug_out,
    output                       debug_in_ready,
    input                        debug_out_ready,

    input mor1kx_trace_exec      trace_port
  );

  localparam ADDR_WIDTH = 32;
  localparam DATA_WIDTH = 32;

  logic                         trace_valid;
  logic [ADDR_WIDTH-1:0]        trace_pc;
  logic [ADDR_WIDTH-1:0]        trace_npc;
  logic                         trace_jal;
  logic                         trace_jalr;
  logic                         trace_branch;
  logic                         trace_load;
  logic                         trace_store;
  logic                         trace_trap;
  logic                         trace_xcpt;
  logic                         trace_mem;
  logic                         trace_csr;
  logic                         trace_br_taken;
  logic [           1:0]        trace_prv;
  logic [ADDR_WIDTH-1:0]        trace_addr;
  logic [DATA_WIDTH-1:0]        trace_rdata;
  logic [DATA_WIDTH-1:0]        trace_wdata;
  logic [DATA_WIDTH-1:0]        trace_time;

  osd_ctm #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .MAX_PKT_LEN(MAX_PKT_LEN)
  )
  u_ctm (.*);

  assign trace_valid = trace_port.valid;
  assign trace_pc    = trace_port.pc;
  assign trace_npc   = trace_port.jbtarget;
  assign trace_jal   = trace_port.jal;
  assign trace_jalr  = trace_port.jr;

  assign trace_branch   = 1'b0;
  assign trace_load     = 1'b0;
  assign trace_store    = 1'b0;
  assign trace_trap     = 1'b0;
  assign trace_xcpt     = 1'b0;
  assign trace_mem      = 1'b0;
  assign trace_csr      = 1'b0;
  assign trace_br_taken = 1'b0;
  assign trace_prv      = 2'b0;
  assign trace_addr     = ADDR_WIDTH'(1'b0);
  assign trace_rdata    = DATA_WIDTH'(1'b0);
  assign trace_wdata    = DATA_WIDTH'(1'b0);
  assign trace_time     = DATA_WIDTH'(1'b0);
endmodule
