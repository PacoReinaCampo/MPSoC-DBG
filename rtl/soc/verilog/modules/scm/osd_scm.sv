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
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module osd_scm #(
  parameter SYSTEM_VENDOR_ID='x,
  parameter SYSTEM_DEVICE_ID='x,
  parameter NUM_MOD='x,
  parameter MAX_PKT_LEN=12
)
  (
    input clk,
    input rst,

    input [15:0] id,

    input  dii_flit debug_in,
    output dii_flit debug_out,

    output debug_in_ready,
    input  debug_out_ready,

    output sys_rst,
    output cpu_rst
  );

  logic        reg_request;
  logic        reg_write;
  logic [15:0] reg_addr;
  logic [ 1:0] reg_size;
  logic [15:0] reg_wdata;
  logic        reg_ack;
  logic        reg_err;
  logic [15:0] reg_rdata;

  logic [ 1:0] rst_vector;

  assign sys_rst = rst_vector[0] | rst;
  assign cpu_rst = rst_vector[1] | rst;

  osd_regaccess #(
    .MOD_VENDOR(16'h1),
    .MOD_TYPE(16'h1),
    .MOD_VERSION(16'h0),
    .MAX_REG_SIZE(16)
  )
  u_regaccess(
    .*,
    .event_dest (),
    .stall ()
  );

  always @(*) begin
    reg_ack = 1;
    reg_rdata = 'x;
    reg_err = 0;

    case (reg_addr)
      16'h200: reg_rdata = 16'(SYSTEM_VENDOR_ID);
      16'h201: reg_rdata = 16'(SYSTEM_DEVICE_ID);
      16'h202: reg_rdata = 16'(NUM_MOD);
      16'h203: reg_rdata = 16'(MAX_PKT_LEN);
      16'h204: reg_rdata = {14'h0, rst_vector};
      default: reg_err   = reg_request;
    endcase
  end

  always @(posedge clk) begin
    if (rst) begin
      rst_vector <= 2'b00;
    end else begin
      if (reg_request & reg_write & (reg_addr == 16'h204))
        rst_vector <= reg_wdata[1:0];
    end
  end
endmodule
