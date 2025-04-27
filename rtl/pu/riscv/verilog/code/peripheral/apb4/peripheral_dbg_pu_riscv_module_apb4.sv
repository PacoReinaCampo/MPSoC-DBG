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
// Copyright (c) 2018-2019 by the author(s)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//   Nathan Yawn <nathan.yawn@opencores.org>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

`include "peripheral_dbg_pu_riscv_pkg.sv"

module peripheral_dbg_pu_riscv_module_apb4 #(
  parameter ADDR_WIDTH = 32,
  parameter DATA_WIDTH = 32,

  parameter DBG_AHB_DATAREG_LEN = 64
) (
  // JTAG signals
  input  tck_i,
  output module_tdo_o,
  input  tdi_i,

  // TAP states
  input tlr_i,
  input capture_dr_i,
  input shift_dr_i,
  input update_dr_i,

  // the data register is at top level, shared between all modules
  input  [DBG_AHB_DATAREG_LEN-1:0] data_register_i,
  input                            module_select_i,
  output                           top_inhibit_o,

  // AHB4 master interface
  input                     HCLK,
  input                     HRESETn,
  output                    HSEL,
  output [ADDR_WIDTH  -1:0] HADDR,
  output [DATA_WIDTH  -1:0] HWDATA,
  input  [DATA_WIDTH  -1:0] HRDATA,
  output                    HWRITE,
  output [             2:0] HSIZE,
  output [             2:0] HBURST,
  output [             3:0] HPROT,
  output [             1:0] HTRANS,
  output                    HMASTLOCK,
  input                     HREADY,
  input                     HRESP
);

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  logic                  biu_clk;
  logic                  biu_rst;
  logic [DATA_WIDTH-1:0] biu_do;
  logic [DATA_WIDTH-1:0] biu_di;
  logic [ADDR_WIDTH-1:0] biu_addr;
  logic                  biu_strb;
  logic                  biu_rw;
  logic                  biu_rdy;
  logic                  biu_err;
  logic [           3:0] biu_word_size;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // Hookup Bus Debug Core
  peripheral_dbg_pu_riscv_bus_module_core #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .DATAREG_LEN(DBG_AHB_DATAREG_LEN)
  ) bus_module_core_inst (
    // Debug Module ports
    .dbg_rst(tlr_i),
    .dbg_clk(tck_i),
    .dbg_tdi(tdi_i),
    .dbg_tdo(module_tdo_o),

    // TAP states
    .capture_dr_i(capture_dr_i),
    .shift_dr_i  (shift_dr_i),
    .update_dr_i (update_dr_i),

    .data_register(data_register_i),  // data register from top-level
    .module_select(module_select_i),
    .inhibit      (top_inhibit_o),

    // Bus Interface Unit ports
    .biu_clk      (biu_clk),
    .biu_rst      (biu_rst),       // TILELINK reset
    .biu_di       (biu_di),        // data towards TILELINK
    .biu_do       (biu_do),        // data from TILELINK
    .biu_addr     (biu_addr),
    .biu_strb     (biu_strb),
    .biu_rw       (biu_rw),
    .biu_rdy      (biu_rdy),
    .biu_err      (biu_err),
    .biu_word_size(biu_word_size)
  );

  // Hookup AHB Bus Interface
  peripheral_dbg_pu_riscv_apb4_tl #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) apb4lite_tl_i (
    // Debug interface signals
    .biu_clk      (biu_clk),
    .biu_rst      (biu_rst),
    .biu_di       (biu_di),
    .biu_do       (biu_do),
    .biu_addr     (biu_addr),
    .biu_strb     (biu_strb),
    .biu_rw       (biu_rw),
    .biu_rdy      (biu_rdy),
    .biu_err      (biu_err),
    .biu_word_size(biu_word_size),

    // AHB Master signals
    .HCLK     (HCLK),
    .HRESETn  (HRESETn),
    .HSEL     (HSEL),
    .HADDR    (HADDR),
    .HWDATA   (HWDATA),
    .HRDATA   (HRDATA),
    .HWRITE   (HWRITE),
    .HSIZE    (HSIZE),
    .HBURST   (HBURST),
    .HPROT    (HPROT),
    .HTRANS   (HTRANS),
    .HMASTLOCK(HMASTLOCK),
    .HREADY   (HREADY),
    .HRESP    (HRESP)
  );
endmodule
