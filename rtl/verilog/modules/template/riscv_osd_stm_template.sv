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

module riscv_osd_stm_template #(
  parameter XLEN     = 64,
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
  logic                       trace_valid;
  logic [XLEN           -1:0] trace_id;
  logic [VALWIDTH       -1:0] trace_value;

  logic                       trace_reg_enable;
  logic [`REG_ADDR_WIDTH-1:0] trace_reg_addr;

  reg [VALWIDTH-1:0] r3_copy;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  riscv_osd_stm #(
    .XLEN     (XLEN),
    .VALWIDTH (VALWIDTH)
  )
  osd_stm (
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

    .trace_valid (trace_valid),
    .trace_id    (trace_id),
    .trace_value (trace_value)
  );

  always @(posedge clk) begin
    if (trace_port_we && (trace_port_addr == 3)) begin
      r3_copy <= trace_port_data;
    end
  end

  assign trace_valid = trace_port_valid &&
                      (trace_port_insn[31:16] == 16'h1500) &&
                      (trace_port_insn[15:0] != 16'h0);

  assign trace_id = trace_port_insn[15:0];
  assign trace_value = r3_copy;
endmodule // osd_stm_mor1kx
