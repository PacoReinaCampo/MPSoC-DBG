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

module osd_dem_uart_wb #(
  parameter DW = 32
)
  (
    input         clk,
    input         rst,

    input   dii_flit debug_in,
    output  dii_flit debug_out,
    output  debug_in_ready,
    input   debug_out_ready,

    input  [15:0] id,

    output        irq,

    input  [   3:0] wb_adr_i,
    input           wb_cyc_i,
    input  [DW-1:0] wb_dat_i,
    input  [   3:0] wb_sel_i,
    input           wb_stb_i,
    input           wb_we_i,
    input  [   2:0] wb_cti_i,
    input  [   1:0] wb_bte_i,

    output          wb_ack_o,
    output          wb_rty_o,
    output          wb_err_o,
    output [DW-1:0] wb_dat_o
  );

  logic          bus_req;
  logic [2:0]    bus_addr;
  logic          bus_write;
  logic [7:0]    bus_wdata;
  logic          bus_ack;
  logic [7:0]    bus_rdata;

  logic          drop;

  logic          out_valid;
  logic [7:0]    out_char;
  logic          out_ready;

  logic          in_valid;
  logic [7:0]    in_char;
  logic          in_ready;

  osd_dem_uart u_uart_emul (
    .clk (clk),
    .rst (rst),

    .id (id),

    .debug_in        (debug_in),
    .debug_in_ready  (debug_in_ready),
    .debug_out       (debug_out),
    .debug_out_ready (debug_out_ready),

    .out_valid (out_valid),
    .out_char  (out_char),
    .out_ready (out_ready),

    .in_valid (in_valid),
    .in_char  (in_char),
    .in_ready (in_ready),

    .drop (drop)
  );

  osd_dem_uart_16550 u_16550 (
    .clk (clk),
    .rst (rst),

    .out_valid (out_valid),
    .out_char  (out_char),
    .out_ready (out_ready),

    .in_valid (in_valid),
    .in_char  (in_char),
    .in_ready (in_ready),

    .bus_req   (bus_req),
    .bus_addr  (bus_addr),
    .bus_write (bus_write),
    .bus_wdata (bus_wdata),
    .bus_ack   (bus_ack),
    .bus_rdata (bus_rdata),

    .drop (drop),

    .irq (irq)
  );

  assign bus_req   = wb_cyc_i & wb_stb_i;
  assign bus_addr  = { wb_adr_i[2], (wb_sel_i[0] ? 2'b11 : (wb_sel_i[1] ? 2'b10 : (wb_sel_i[2] ? 2'b01 : 2'b00))) };
  assign bus_write = wb_we_i;
  assign bus_wdata = wb_dat_i[7:0];

  assign wb_ack_o = bus_ack;
  assign wb_err_o = 1'b0;
  assign wb_rty_o = 1'b0;
  assign wb_dat_o = {4{bus_rdata}};
endmodule
