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

module riscv_osd_ctm #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter MAX_REG_SIZE = 64,

  parameter ADDR_WIDTH = 64,
  parameter DATA_WIDTH = 64
)
  (
    input                   clk,
    input                   rst,

    input  [XLEN      -1:0] id,

    input  [DATA_WIDTH-1:0] debug_in_data,
    input                   debug_in_last,
    input                   debug_in_valid,
    output                  debug_in_ready,

    output [DATA_WIDTH-1:0] debug_out_data,
    output                  debug_out_last,
    output                  debug_out_valid,
    input                   debug_out_ready,

    input                   trace_valid,
    input  [ADDR_WIDTH-1:0] trace_pc,
    input  [ADDR_WIDTH-1:0] trace_npc,
    input                   trace_jal,
    input                   trace_jalr,
    input                   trace_branch,
    input                   trace_load,
    input                   trace_store,
    input                   trace_trap,
    input                   trace_xcpt,
    input                   trace_mem,
    input                   trace_csr,
    input                   trace_br_taken,
    input  [           1:0] trace_prv,
    input  [ADDR_WIDTH-1:0] trace_addr,
    input  [DATA_WIDTH-1:0] trace_rdata,
    input  [DATA_WIDTH-1:0] trace_wdata,
    input  [DATA_WIDTH-1:0] trace_time
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  localparam EW = 3 + XLEN + 2 + ADDR_WIDTH + ADDR_WIDTH;

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

  logic                   stall;
  logic [XLEN       -1:0] event_dest;

  logic [DATA_WIDTH -1:0] dp_in_data;
  logic                   dp_in_last;
  logic                   dp_in_valid;
  logic                   dp_in_ready;

  logic [DATA_WIDTH -1:0] dp_out_data;
  logic                   dp_out_last;
  logic                   dp_out_valid;
  logic                   dp_out_ready;

  reg   [            1:0] prv_reg;

  logic [EW         -1:0] sample_data;
  logic                   sample_valid;
  logic [XLEN       -1:0] timestamp;
  logic [EW         -1:0] fifo_data;
  logic                   fifo_overflow;
  logic                   fifo_valid;
  logic                   fifo_ready;
  logic [EW         -1:0] packet_data;
  logic                   packet_overflow;
  logic                   packet_valid;
  logic                   packet_ready;

  logic                   sample_prvchange;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  riscv_osd_regaccess_layer #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .MAX_REG_SIZE (MAX_REG_SIZE)
  )
  osd_regaccess_layer (
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

    .module_in_data  (dp_out_data),
    .module_in_last  (dp_out_last),
    .module_in_valid (dp_out_valid),
    .module_in_ready (dp_out_ready),

    .module_out_data  (dp_in_data),
    .module_out_last  (dp_in_last),
    .module_out_valid (dp_in_valid),
    .module_out_ready (dp_in_ready),

    .reg_request (reg_request),
    .reg_write   (reg_write),
    .reg_addr    (reg_addr),
    .reg_size    (reg_size),
    .reg_wdata   (reg_wdata),
    .reg_ack     (reg_ack),
    .reg_err     (reg_err),
    .reg_rdata   (reg_rdata),

    .event_dest (event_dest),
    .stall      (stall)
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
    endcase // case (reg_addr)
  end // always @ (*)

  always @(posedge clk) begin
    prv_reg <= trace_prv;
  end

  assign sample_prvchange = (prv_reg != trace_prv);
  assign sample_valid = (trace_valid & !trace_mem &
                        (trace_jal | trace_jalr)) | sample_prvchange;
  assign sample_data = {sample_prvchange, trace_jal, trace_jalr,
                        trace_prv, trace_pc, trace_npc, timestamp};

  always @(posedge clk) begin
    if (rst)
      timestamp <= 0;
    else 
      timestamp <= timestamp + 1;
  end

  riscv_osd_tracesample #(
    .WIDTH (EW)
  )
  osd_tracesample (
    .clk            (clk),
    .rst            (rst),
    .sample_data    (sample_data),
    .sample_valid   (sample_valid & !stall),

    .fifo_data      (fifo_data),
    .fifo_overflow  (fifo_overflow),
    .fifo_valid     (fifo_valid),
    .fifo_ready     (fifo_ready)
  );

  riscv_osd_fifo #(
    .WIDTH (EW+1),
    .DEPTH (8)
  )
  osd_fifo (
    .clk       (clk),
    .rst       (rst),

    .in_data   ({fifo_overflow, fifo_data}),
    .in_valid  (fifo_valid),
    .in_ready  (fifo_ready),

    .out_data  ({packet_overflow, packet_data}),
    .out_valid (packet_valid),
    .out_ready (packet_ready)
  );

  riscv_osd_event_packetization_fixedwidth #(
    .XLEN (XLEN),

    .DATA_WIDTH (EW)
  )
  osd_event_packetization_fixedwidth (
    .clk             (clk),
    .rst             (rst),

    .debug_out_data  (dp_out_data),
    .debug_out_last  (dp_out_last),
    .debug_out_valid (dp_out_valid),
    .debug_out_ready (dp_out_ready),

    .id              (id),
    .dest            (event_dest),
    .overflow        (packet_overflow),
    .event_available (packet_valid),
    .event_consumed  (packet_ready),

    .data            (packet_data)
  );
endmodule // osd_ctm
