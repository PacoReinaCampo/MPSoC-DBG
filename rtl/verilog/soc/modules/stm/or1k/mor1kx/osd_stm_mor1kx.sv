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

module osd_stm_mor1kx #(
  parameter MAX_PKT_LEN = 'hx
)
  (
    input                        clk,
    input                        rst,

    input                 [15:0] id,

    input  dii_flit              debug_in,
    output                       debug_in_ready,
    output dii_flit              debug_out,
    input                        debug_out_ready,

    input  mor1kx_trace_exec     trace_port
  );

  localparam VALWIDTH       = 32;
  localparam REG_ADDR_WIDTH = 5;

  logic                         trace_valid;
  logic [              15:0]    trace_id;
  logic [VALWIDTH      -1:0]    trace_value;

  logic                         trace_reg_enable;
  logic [REG_ADDR_WIDTH-1:0]    trace_reg_addr;

  reg   [              31:0]    r3_copy;

  osd_stm #(
    .REG_ADDR_WIDTH (REG_ADDR_WIDTH),
    .VALWIDTH       (VALWIDTH),
    .MAX_PKT_LEN    (MAX_PKT_LEN)
  )
  u_stm (.*);

  always @(posedge clk) begin
    if (trace_port.wben && (trace_port.wbreg == 3)) begin
      r3_copy <= trace_port.wbdata;
    end
  end

  assign trace_valid = trace_port.valid &&
                      (trace_port.insn[31:16] == 16'h1500) &&
                      (trace_port.insn[15:0] != 16'h0);

  assign trace_id    = trace_port.insn[15:0];
  assign trace_value = r3_copy;
endmodule
