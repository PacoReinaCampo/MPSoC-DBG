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

`include "riscv_mpsoc_pkg.sv"
`include "riscv_dbg_pkg.sv"

module riscv_osd_scm #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter MAX_REG_SIZE = 64
)
  (
    input              clk,
    input              rst,

    input  [XLEN -1:0] id,

    input  [XLEN -1:0] debug_in_data,
    input              debug_in_last,
    input              debug_in_valid,
    output             debug_in_ready,

    output [XLEN -1:0] debug_out_data,
    output             debug_out_last,
    output             debug_out_valid,
    input              debug_out_ready,

    output sys_rst,
    output cpu_rst
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic                    reg_request;
  logic                    reg_write;
  logic [PLEN        -1:0] reg_addr;
  logic [             1:0] reg_size;
  logic [MAX_REG_SIZE-1:0] reg_wdata;
  logic                    reg_ack;
  logic                    reg_err;
  logic [MAX_REG_SIZE-1:0] reg_rdata;

  logic [             1:0] rst_vector;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign sys_rst = rst_vector[0] | rst;
  assign cpu_rst = rst_vector[1] | rst;

  riscv_osd_regaccess #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .MAX_REG_SIZE (MAX_REG_SIZE)
  )
  osd_regaccess (
    .clk (clk),
    .rst (rst),

    .id (id),

    .debug_in_data  (debug_in_data),
    .debug_in_last  (debug_in_last),
    .debug_in_valid (debug_in_valid),
    .debug_in_ready (debug_in_ready),

    .debug_out_data  (debug_out_data),
    .debug_out_last  (debug_out_last),
    .debug_out_valid (debug_out_valid),
    .debug_out_ready (debug_out_ready),

    .reg_request (reg_request),
    .reg_write   (reg_write),
    .reg_addr    (reg_addr),
    .reg_size    (reg_size),
    .reg_wdata   (reg_wdata),
    .reg_ack     (reg_ack),
    .reg_err     (reg_err),
    .reg_rdata   (reg_rdata),

    .event_dest (),
    .stall      ()
  );

  always @(*) begin
    reg_ack   = 1;
    reg_rdata = 'x;
    reg_err   = 0;

    case (reg_addr)
      16'h200: reg_rdata = 16'(`SYSTEM_VENDOR_ID);
      16'h201: reg_rdata = 16'(`SYSTEM_DEVICE_ID);
      16'h202: reg_rdata = 16'(`NUM_MODULES);
      16'h203: reg_rdata = 16'(`MAX_PKT_LEN);
      16'h204: reg_rdata = {14'h0, rst_vector};
      default: reg_err   = reg_request;
    endcase // case (reg_addr)
  end // always @ (*)

  always @(posedge clk) begin
    if (rst) begin
      rst_vector <= 2'b00;
    end
    else begin
      if (reg_request & reg_write & (reg_addr == 64'h204))
        rst_vector <= reg_wdata[1:0];
    end
  end
endmodule
