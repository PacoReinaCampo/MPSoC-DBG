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
//              AMBA4 AHB-Lite Bus Interface                                  //
//              WishBone Bus Interface                                        //
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
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

module peripheral_dbg_testbench;

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  parameter X = 2;
  parameter Y = 2;
  parameter Z = 2;

  parameter CORES_PER_TILE = 4;

  parameter ADDR_WIDTH = 32;
  parameter DATA_WIDTH = 32;

  parameter CPU_ADDR_WIDTH = 32;
  parameter CPU_DATA_WIDTH = 32;

  parameter DATAREG_LEN = 64;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // TILELINK

  // JTAG signals
  logic                                                                          biu_tck_i;
  logic                                                                          biu_tdi_i;
  logic                                                                          biu_tdo_o;

  // TAP states
  logic                                                                          biu_tlr_i;  // TestLogicReset
  logic                                                                          biu_shift_dr_i;
  logic                                                                          biu_pause_dr_i;
  logic                                                                          biu_update_dr_i;
  logic                                                                          biu_capture_dr_i;

  // Instructions
  logic                                                                          biu_debug_select_i;

  // AHB Master Interface Signals
  logic                                                                          HCLK;
  logic                                                                          HRESETn;
  logic                                                                          dbg_HSEL;
  logic [ADDR_WIDTH  -1:0]                                                       dbg_HADDR;
  logic [DATA_WIDTH  -1:0]                                                       dbg_HWDATA;
  logic [DATA_WIDTH  -1:0]                                                       dbg_HRDATA;
  logic                                                                          dbg_HWRITE;
  logic [             2:0]                                                       dbg_HSIZE;
  logic [             2:0]                                                       dbg_HBURST;
  logic [             3:0]                                                       dbg_HPROT;
  logic [             1:0]                                                       dbg_HTRANS;
  logic                                                                          dbg_HMASTLOCK;
  logic                                                                          dbg_HREADY;
  logic                                                                          dbg_HRESP;

  // APB Slave Interface Signals (JTAG Serial Port)
  logic                                                                          PRESETn;
  logic                                                                          PCLK;
  logic                                                                          jsp_PSEL;
  logic                                                                          jsp_PENABLE;
  logic                                                                          jsp_PWRITE;
  logic [             2:0]                                                       jsp_PADDR;
  logic [             7:0]                                                       jsp_PWDATA;
  logic [             7:0]                                                       jsp_PRDATA;
  logic                                                                          jsp_PREADY;
  logic                                                                          jsp_PSLVERR;

  logic                                                                          int_o;

  // CPU/Thread debug ports
  logic                                                                          biu_cpu_clk_i;
  logic                                                                          biu_cpu_rstn_i;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_ADDR_WIDTH-1:0] biu_cpu_addr_o;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] biu_cpu_data_i;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] biu_cpu_data_o;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     biu_cpu_bp_i;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     biu_cpu_stall_o;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     biu_cpu_stb_o;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     biu_cpu_we_o;
  logic [           X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     biu_cpu_ack_i;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // DUT TILELINK
  peripheral_dbg_pu_riscv_top_tl #(
    .X(X),
    .Y(Y),
    .Z(Z),

    .CORES_PER_TILE(CORES_PER_TILE),

    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),

    .CPU_ADDR_WIDTH(CPU_ADDR_WIDTH),
    .CPU_DATA_WIDTH(CPU_DATA_WIDTH),

    .DATAREG_LEN(DATAREG_LEN)
  ) dbg_pu_riscv_top_tl (
    // JTAG signals
    .tck_i(biu_tck_i),
    .tdi_i(biu_tdi_i),
    .tdo_o(biu_tdo_i),

    // TAP states
    .tlr_i       (biu_tlr_i),
    .shift_dr_i  (biu_shift_dr_i),
    .pause_dr_i  (biu_pause_dr_i),
    .update_dr_i (biu_update_dr_i),
    .capture_dr_i(biu_capture_dr_i),

    // Instructions
    .debug_select_i(biu_debug_select_i),

    // AHB Master Interface Signals
    .HCLK         (HCLK),
    .HRESETn      (HRESETn),
    .dbg_HSEL     (dbg_HSEL),
    .dbg_HADDR    (dbg_HADDR),
    .dbg_HWDATA   (dbg_HWDATA),
    .dbg_HRDATA   (dbg_HRDATA),
    .dbg_HWRITE   (dbg_HWRITE),
    .dbg_HSIZE    (dbg_HSIZE),
    .dbg_HBURST   (dbg_HBURST),
    .dbg_HPROT    (dbg_HPROT),
    .dbg_HTRANS   (dbg_HTRANS),
    .dbg_HMASTLOCK(dbg_HMASTLOCK),
    .dbg_HREADY   (dbg_HREADY),
    .dbg_HRESP    (dbg_HRESP),

    // APB Slave Interface Signals (JTAG Serial Port)
    .PRESETn    (PRESETn),
    .PCLK       (PCLK),
    .jsp_PSEL   (jsp_PSEL),
    .jsp_PENABLE(jsp_PENABLE),
    .jsp_PWRITE (jsp_PWRITE),
    .jsp_PADDR  (jsp_PADDR),
    .jsp_PWDATA (jsp_PWDATA),
    .jsp_PRDATA (jsp_PRDATA),
    .jsp_PREADY (jsp_PREADY),
    .jsp_PSLVERR(jsp_PSLVERR),

    .int_o(int_o),

    // CPU/Thread debug ports
    .cpu_clk_i  (biu_cpu_clk_i),
    .cpu_rstn_i (biu_cpu_rstn_i),
    .cpu_addr_o (biu_cpu_addr_o),
    .cpu_data_i (biu_cpu_data_i),
    .cpu_data_o (biu_cpu_data_o),
    .cpu_bp_i   (biu_cpu_bp_i),
    .cpu_stall_o(biu_cpu_stall_o),
    .cpu_stb_o  (biu_cpu_stb_o),
    .cpu_we_o   (biu_cpu_we_o),
    .cpu_ack_i  (biu_cpu_ack_i)
  );
endmodule
