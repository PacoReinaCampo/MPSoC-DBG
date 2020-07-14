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
 *   Nico Gutmann <nicolai.gutmann@gmail.com>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module osd_mam_wb #(
  parameter DATA_WIDTH  = 16, // in bits, must be multiple of 16
  parameter ADDR_WIDTH  = 32,

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
  localparam SW = (DATA_WIDTH == 32) ? 4 :
                  (DATA_WIDTH == 16) ? 2 :
                  (DATA_WIDTH ==  8) ? 1 : 'hx
)
  (
    input clk_i,
    input rst_i,

    input  dii_flit debug_in,
    output dii_flit debug_out,
    output debug_in_ready,
    input  debug_out_ready,

    input [15:0] id,

    output                  stb_o,
    output                  cyc_o,
    input                   ack_i,
    output                  we_o,
    output [ADDR_WIDTH-1:0] addr_o,
    output [DATA_WIDTH-1:0] dat_o,
    input  [DATA_WIDTH-1:0] dat_i,
    output [           2:0] cti_o,
    output [           1:0] bte_o,
    output [SW        -1:0] sel_o
  );

  logic                        req_valid;
  logic                        req_ready;
  logic                        req_we;
  logic [ADDR_WIDTH  -1:0]     req_addr;
  logic                        req_burst;
  logic [            12:0]     req_beats;
  logic                        req_sync;

  logic                        write_valid;
  logic [DATA_WIDTH  -1:0]     write_data;
  logic [DATA_WIDTH/8-1:0]     write_strb;
  logic                        write_ready;
  logic                        write_complete;

  logic                        read_valid;
  logic [DATA_WIDTH  -1:0]     read_data;
  logic                        read_ready;

  osd_mam #(
    .DATA_WIDTH (DATA_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),

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
    .clk(clk_i),
    .rst(rst_i) 
  );

  assign write_complete = 1'b1;

  osd_mam_wb_if #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  )
  u_mam_wb_if(.*);
endmodule
