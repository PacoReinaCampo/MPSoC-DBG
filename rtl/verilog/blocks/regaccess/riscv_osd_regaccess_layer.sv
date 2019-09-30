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

module riscv_osd_regaccess_layer #(
  parameter XLEN = 64,
  parameter PLEN = 64,

  parameter MAX_REG_SIZE = 64
)
  (
    input                     clk,
    input                     rst,

    input        [XLEN  -1:0] id,

    input        [XLEN  -1:0] debug_in_data,
    input                     debug_in_last,
    input                     debug_in_valid,
    output                    debug_in_ready,

    output       [XLEN  -1:0] debug_out_data,
    output                    debug_out_last,
    output                    debug_out_valid,
    input                     debug_out_ready,

    input        [XLEN  -1:0] module_in_data,
    input                     module_in_last,
    input                     module_in_valid,
    output                    module_in_ready,

    output       [XLEN  -1:0] module_out_data,
    output                    module_out_last,
    output                    module_out_valid,
    input                     module_out_ready,

    output reg                reg_request,
    output                    reg_write,
    output [PLEN        -1:0] reg_addr,
    output [             1:0] reg_size,
    output [MAX_REG_SIZE-1:0] reg_wdata,
    input                     reg_ack,
    input                     reg_err,
    input  [MAX_REG_SIZE-1:0] reg_rdata,

    output [XLEN        -1:0] event_dest, // DI address of the event destination
    output                    stall
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [XLEN  -1:0] regaccess_in_data;
  logic              regaccess_in_last;
  logic              regaccess_in_valid;
  logic              regaccess_in_ready;

  logic [XLEN  -1:0] regaccess_out_data;
  logic              regaccess_out_last;
  logic              regaccess_out_valid;
  logic              regaccess_out_ready;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  riscv_osd_regaccess #(
    .XLEN (XLEN),
    .PLEN (PLEN),

    .MAX_REG_SIZE (MAX_REG_SIZE)
  )
  osd_regaccess (
    .clk (clk),
    .rst (rst),

    .id (id),

    .debug_in_data   (regaccess_in_data),
    .debug_in_last   (regaccess_in_last),
    .debug_in_valid  (regaccess_in_valid),
    .debug_in_ready  (regaccess_in_ready),

    .debug_out_data  (regaccess_out_data),
    .debug_out_last  (regaccess_out_last),
    .debug_out_valid (regaccess_out_valid),
    .debug_out_ready (regaccess_out_ready),

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

  // Ingress path demux
  riscv_osd_regaccess_demux #(
    .XLEN (XLEN)
  )
  osd_regaccess_demux (
    .clk (clk),
    .rst (rst),

    .in_data          (debug_in_data),
    .in_last          (debug_in_last),
    .in_valid         (debug_in_valid),
    .in_ready         (debug_in_ready),

    .out_reg_data     (regaccess_in_data),
    .out_reg_last     (regaccess_in_last),
    .out_reg_valid    (regaccess_in_valid),
    .out_reg_ready    (regaccess_in_ready),

    .out_bypass_data  (module_out_data),
    .out_bypass_last  (module_out_last),
    .out_bypass_valid (module_out_valid),
    .out_bypass_ready (module_out_ready)
  );

  // Egress path mux
  riscv_ring_router_mux #(
    .XLEN (XLEN)
  )
  ring_router_mux (
    .clk (clk),
    .rst (rst),

    .in_local_data  (module_in_data),
    .in_local_last  (module_in_last),
    .in_local_valid (module_in_valid),
    .in_local_ready (module_in_ready),

    .in_ring_data   (regaccess_out_data),
    .in_ring_last   (regaccess_out_last),
    .in_ring_valid  (regaccess_out_valid),
    .in_ring_ready  (regaccess_out_ready),

    .out_mux_data   (debug_out_data),
    .out_mux_last   (debug_out_last),
    .out_mux_valid  (debug_out_valid),
    .out_mux_ready  (debug_out_ready)
  );
endmodule
