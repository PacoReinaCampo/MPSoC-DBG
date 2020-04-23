// Copyright 2016 by the authors
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
//    Nico Gutmann <nicolai.gutmann@gmail.com>

import dii_package::dii_flit;

module osd_mam_ahb3 #(
  parameter XLEN = 16, // in bits, must be multiple of 16
  parameter PLEN = 32,

  parameter MAX_PKT_LEN = 'x,
  parameter REGIONS     = 1,
  parameter MEM_SIZE0   = 'x,
  parameter BASE_ADDR0  = 'x,
  parameter MEM_SIZE1   = 'x,
  parameter BASE_ADDR1  = 'x,
  parameter MEM_SIZE2   = 'x,
  parameter BASE_ADDR2  = 'x,
  parameter MEM_SIZE3   = 'x,
  parameter BASE_ADDR3  = 'x,
  parameter MEM_SIZE4   = 'x,
  parameter BASE_ADDR4  = 'x,
  parameter MEM_SIZE5   = 'x,
  parameter BASE_ADDR5  = 'x,
  parameter MEM_SIZE6   = 'x,
  parameter BASE_ADDR6  = 'x,
  parameter MEM_SIZE7   = 'x,
  parameter BASE_ADDR7  = 'x,

  //Byte select width
  localparam SW = (XLEN == 32) ? 4 :
                  (XLEN == 16) ? 2 :
                  (XLEN ==  8) ? 1 : 'hx
)
  (
    input clk_i,
    input rst_i,

    input  dii_flit debug_in,
    output dii_flit debug_out,
    output debug_in_ready,
    input  debug_out_ready,

    input [15:0] id,

    output            ahb3_hsel_o,
    output [    15:0] ahb3_haddr_o,
    output [XLEN-1:0] ahb3_hwdata_o,
    output            ahb3_hwrite_o,
    output [     2:0] ahb3_hsize_o,
    output [     2:0] ahb3_hburst_o,
    output [     3:0] ahb3_hprot_o,
    output [     1:0] ahb3_htrans_o,
    output            ahb3_hmastlock_o,

    input  [XLEN-1:0] ahb3_hrdata_i,
    input             ahb3_hready_i,
    input             ahb3_hresp_i
  );

  logic              req_valid;
  logic              req_ready;
  logic              req_we;
  logic [PLEN  -1:0] req_addr;
  logic              req_burst;
  logic [      12:0] req_beats;
  logic              req_sync;

  logic              write_valid;
  logic [XLEN  -1:0] write_data;
  logic [XLEN/8-1:0] write_strb;
  logic              write_ready;
  logic              write_complete;

  logic              read_valid;
  logic [XLEN  -1:0] read_data;
  logic              read_ready;

  osd_mam #(
    .ADDR_WIDTH (PLEN),
    .DATA_WIDTH (XLEN),

    .MAX_PKT_LEN(MAX_PKT_LEN),
    .REGIONS(REGIONS),
    .BASE_ADDR0(BASE_ADDR0),
    .MEM_SIZE0(MEM_SIZE0),
    .BASE_ADDR1(BASE_ADDR1),
    .MEM_SIZE1(MEM_SIZE1),
    .BASE_ADDR2(BASE_ADDR2),
    .MEM_SIZE2(MEM_SIZE2),
    .BASE_ADDR3(BASE_ADDR3),
    .MEM_SIZE3(MEM_SIZE3),
    .BASE_ADDR4(BASE_ADDR4),
    .MEM_SIZE4(MEM_SIZE4),
    .BASE_ADDR5(BASE_ADDR5),
    .MEM_SIZE5(MEM_SIZE5),
    .BASE_ADDR6(BASE_ADDR6),
    .MEM_SIZE6(MEM_SIZE6),
    .BASE_ADDR7(BASE_ADDR7),
    .MEM_SIZE7(MEM_SIZE7)
  )
  u_mam (
    .*,
    .clk (clk_i),
    .rst (rst_i)
  );

  assign write_complete = 1'b1;

  osd_mam_ahb3_if #(
    .XLEN(XLEN),
    .PLEN(PLEN)
  )
  u_mam_ahb3_if (.*);
endmodule
