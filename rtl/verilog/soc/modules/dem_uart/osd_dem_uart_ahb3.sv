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

module osd_dem_uart_ahb3 #(
  parameter XLEN = 32
)
  (
    input         clk,
    input         rst,

    input   dii_flit debug_in,
    output  debug_in_ready,
    output  dii_flit debug_out,
    input   debug_out_ready,

    input [15:0]  id,

    output        irq,

    input             ahb3_hsel_i,
    input  [    15:0] ahb3_haddr_i,
    input  [XLEN-1:0] ahb3_hwdata_i,
    output [XLEN-1:0] ahb3_hrdata_o,
    input             ahb3_hwrite_i,
    input  [     2:0] ahb3_hsize_i,
    input  [     2:0] ahb3_hburst_i,
    input  [     3:0] ahb3_hprot_i,
    input  [     1:0] ahb3_htrans_i,
    input             ahb3_hmastlock_i,
    output            ahb3_hready_o,
    output            ahb3_hresp_o
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
    .debug_in (debug_in),
    .debug_in_ready (debug_in_ready),
    .debug_out (debug_out),
    .debug_out_ready (debug_out_ready),
    .out_valid (out_valid),
    .out_char (out_char),
    .out_ready (out_ready),
    .in_valid (in_valid),
    .in_char (in_char),
    .in_ready (in_ready),
    .drop (drop)
  );

  osd_dem_uart_16550 u_16550 (
    .clk (clk), .rst (rst),
    .out_valid (out_valid),
    .out_char (out_char),
    .out_ready (out_ready),
    .in_valid (in_valid),
    .in_char (in_char),
    .in_ready (in_ready),
    .bus_req (bus_req),
    .bus_addr (bus_addr),
    .bus_write (bus_write),
    .bus_wdata (bus_wdata),
    .bus_ack (bus_ack),
    .bus_rdata (bus_rdata),
    .drop (drop),
    .irq (irq)
  );

  assign bus_req = ahb3_hmastlock_i & ahb3_hsel_i;
  assign bus_addr = { ahb3_haddr_i[2], (ahb3_hprot_i[0] ? 2'b11 : (ahb3_hprot_i[1] ? 2'b10 : (ahb3_hprot_i[2] ? 2'b01 : 2'b00))) };
  assign bus_write = ahb3_hwrite_i;
  assign bus_wdata = ahb3_hwdata_i[7:0];
  assign ahb3_hready_o = bus_ack;
  assign ahb3_hresp_o = 1'b0;
  assign ahb3_hrdata_o = {4{bus_rdata}};
endmodule
