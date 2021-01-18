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

module osd_ctm #(
  parameter ADDR_WIDTH  = 64,  // width of memory addresses
  parameter DATA_WIDTH  = 64,  // system word length
  parameter MAX_PKT_LEN = 'hx  // maximum length of a DI packet in flits
)
  (
    input                  clk,
    input                  rst,

    input [          15:0] id,

    input                  dii_flit debug_in,
    output                 debug_in_ready,
    output                 dii_flit debug_out,
    input                  debug_out_ready,

    input                  trace_valid,
    input [ADDR_WIDTH-1:0] trace_pc,
    input [ADDR_WIDTH-1:0] trace_npc,
    input                  trace_jal,
    input                  trace_jalr,
    input                  trace_branch,
    input                  trace_load,
    input                  trace_store,
    input                  trace_trap,
    input                  trace_xcpt,
    input                  trace_mem,
    input                  trace_csr,
    input                  trace_br_taken,
    input [           1:0] trace_prv,
    input [ADDR_WIDTH-1:0] trace_addr,
    input [DATA_WIDTH-1:0] trace_rdata,
    input [DATA_WIDTH-1:0] trace_wdata,
    input [DATA_WIDTH-1:0] trace_time
  );

  localparam EW = 3 + 32 + 2 + ADDR_WIDTH + ADDR_WIDTH;

  logic                   reg_request;
  logic                   reg_write;
  logic [15:0]            reg_addr;
  logic [ 1:0]            reg_size;
  logic [15:0]            reg_wdata;
  logic                   reg_ack;
  logic                   reg_err;
  logic [15:0]            reg_rdata;

  logic                   stall;
  logic [15:0]            event_dest;

  dii_flit                dp_out, dp_in;

  logic                   dp_out_ready, dp_in_ready;

  reg   [   1:0]          prv_reg;

  logic [EW-1:0]          sample_data;
  logic                   sample_valid;
  logic [  31:0]          timestamp;
  logic [EW-1:0]          fifo_data;
  logic                   fifo_overflow;
  logic                   fifo_valid;
  logic                   fifo_ready;
  logic [EW-1:0]          packet_data;
  logic                   packet_overflow;
  logic                   packet_valid;
  logic                   packet_ready;

  logic                   sample_prvchange;

  osd_regaccess_layer #(
    .MOD_VENDOR(16'h1),
    .MOD_TYPE(16'h5),
    .MOD_VERSION(16'h0),
    .MAX_REG_SIZE(16),
    .CAN_STALL(1)
  )
  u_regaccess (
    .*,
    .event_dest (event_dest),
    .module_in (dp_out),
    .module_in_ready (dp_out_ready),
    .module_out (dp_in),
    .module_out_ready (dp_in_ready)
  );

  // this module cannot receive data except for configuration packets
  assign dp_in_ready = 1'b0;

  always @(*) begin
    reg_ack = 1;
    reg_rdata = 'x;
    reg_err = 0;

    case (reg_addr)
      16'h200: reg_rdata = 16'(ADDR_WIDTH);
      16'h201: reg_rdata = 16'(DATA_WIDTH);
      default: reg_err = reg_request;
    endcase
  end

  always_ff @(posedge clk) begin
    prv_reg <= trace_prv;
  end

  assign sample_prvchange = (prv_reg != trace_prv);

  assign sample_valid = (trace_valid & !trace_mem &
                        (trace_jal | trace_jalr)) | sample_prvchange;

  assign sample_data = {sample_prvchange, trace_jal, trace_jalr,
                        trace_prv, trace_pc, trace_npc, timestamp};

  osd_timestamp #(
    .WIDTH(32)
  )
  u_timestamp(
    .clk  (clk),
    .rst  (rst),
    .enable (1),
    .timestamp (timestamp)
  );

  osd_tracesample #(
    .WIDTH(EW)
  )
  u_sample (
    .clk            (clk),
    .rst            (rst),
    .sample_data    (sample_data),
    .sample_valid   (sample_valid & !stall),
    .fifo_data      (fifo_data),
    .fifo_overflow  (fifo_overflow),
    .fifo_valid     (fifo_valid),
    .fifo_ready     (fifo_ready)
  );

  osd_fifo #(
    .WIDTH(EW+1),
    .DEPTH(8)
  )
  u_buffer(
    .clk (clk),
    .rst (rst),

    .in_data   ({fifo_overflow, fifo_data}),
    .in_valid  (fifo_valid),
    .in_ready  (fifo_ready),
    .out_data  ({packet_overflow, packet_data}),
    .out_valid (packet_valid),
    .out_ready (packet_ready)
  );

  osd_event_packetization_fixedwidth #(
    .DATA_WIDTH(EW),
    .MAX_PKT_LEN(MAX_PKT_LEN)
  )
  u_packetization (
    .clk             (clk),
    .rst             (rst),

    .debug_out       (dp_out),
    .debug_out_ready (dp_out_ready),

    .id              (id),

    .dest            (event_dest),
    .overflow        (packet_overflow),
    .event_available (packet_valid),
    .event_consumed  (packet_ready),

    .data            (packet_data)
  );
endmodule
