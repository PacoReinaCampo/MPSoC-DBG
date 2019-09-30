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

module riscv_osd_ctm_template #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter MAX_REG_SIZE = 64,

  parameter ADDR_WIDTH = 64,
  parameter DATA_WIDTH = 64,

  parameter VALWIDTH = 2
)
  (
    input                 clk,
    input                 rst,

    input  [XLEN    -1:0] id,

    input  [XLEN    -1:0] debug_in_data,
    input                 debug_in_last,
    input                 debug_in_valid,
    output                debug_in_ready,

    output [XLEN    -1:0] debug_out_data,
    output                debug_out_last,
    output                debug_out_valid,
    input                 debug_out_ready,

    input  [XLEN    -1:0] trace_port_insn,
    input  [XLEN    -1:0] trace_port_pc,
    input                 trace_port_jb,
    input                 trace_port_jal,
    input                 trace_port_jr,
    input  [XLEN    -1:0] trace_port_jbtarget,
    input                 trace_port_valid,
    input  [VALWIDTH-1:0] trace_port_data,
    input  [         4:0] trace_port_addr,
    input                 trace_port_we
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
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

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  riscv_osd_ctm #(
  .XLEN (XLEN),
  .PLEN (PLEN),

  .MAX_REG_SIZE (MAX_REG_SIZE),

  .ADDR_WIDTH (ADDR_WIDTH),
  .DATA_WIDTH (DATA_WIDTH)
  )
  osd_ctm (
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

    .trace_valid    (trace_valid),
    .trace_pc       (trace_pc),
    .trace_npc      (trace_npc),
    .trace_jal      (trace_jal),
    .trace_jalr     (trace_jalr),
    .trace_branch   (trace_branch),
    .trace_load     (trace_load),
    .trace_store    (trace_store),
    .trace_trap     (trace_trap),
    .trace_xcpt     (trace_xcpt),
    .trace_mem      (trace_mem),
    .trace_csr      (trace_csr),
    .trace_br_taken (trace_br_taken),
    .trace_prv      (trace_prv),
    .trace_addr     (trace_addr),
    .trace_rdata    (trace_rdata),
    .trace_wdata    (trace_wdata),
    .trace_time     (trace_time)
  );

  assign trace_valid = trace_port_valid;
  assign trace_pc    = trace_port_pc;
  assign trace_npc   = trace_port_jbtarget;
  assign trace_jal   = trace_port_jal;
  assign trace_jalr  = trace_port_jr;

  assign trace_branch   = 1'b0;
  assign trace_load     = 1'b0;
  assign trace_store    = 1'b0;
  assign trace_trap     = 1'b0;
  assign trace_xcpt     = 1'b0;
  assign trace_mem      = 1'b0;
  assign trace_csr      = 1'b0;
  assign trace_br_taken = 1'b0;

  assign trace_prv      = 2'b0;

  assign trace_addr     = 'b0;
  assign trace_rdata    = 'b0;
  assign trace_wdata    = 'b0;
  assign trace_time     = 'b0;
endmodule // osd_stm_mor1kx
