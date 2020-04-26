// Copyright 2017 by the authors
//
// Copyright and related rights are licensed under the Solderpad
// Hardware License, Version 0.51 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a
// copy of the License at http://solderpad.org/licenses/SHL-0.51.
// Unless required by applicable law or agreed to in writing,
// software, hardware and materials distributed under this License is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the
// License.
//
// Authors:
//    Stefan Wallentowitz <stefan@wallentowitz.de>

import dii_package::dii_flit;

module osd_dem_uart_bb #(
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

    input  [   3:0] bb_addr_i,
    input  [DW-1:0] bb_din_i,
    input           bb_en_i,
    input           bb_we_i,

    output [DW-1:0] bb_dout_o
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

  assign bus_req   = bb_en_i;
  assign bus_addr  = bb_addr_i;
  assign bus_write = bb_we_i;
  assign bus_wdata = bb_din_i[7:0];

  assign bb_dout_o = {4{bus_rdata}};
endmodule
