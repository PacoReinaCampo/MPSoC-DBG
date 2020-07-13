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
//              WishBone Bus Interface                                        //
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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

module mpsoc_dbg_testbench;

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  parameter X              = 2;
  parameter Y              = 2;
  parameter Z              = 2;

  parameter CORES_PER_TILE = 4;

  parameter ADDR_WIDTH     = 32;
  parameter DATA_WIDTH     = 32;

  parameter CPU_ADDR_WIDTH = 32;
  parameter CPU_DATA_WIDTH = 32;

  parameter DATAREG_LEN    = 64;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // WB

  // JTAG signals
  logic                    wb_tck_i;
  logic                    wb_tdi_i;
  logic                    wb_tdo_o;

  // TAP states
  logic                    wb_tlr_i;  //TestLogicReset
  logic                    wb_shift_dr_i;
  logic                    wb_pause_dr_i;
  logic                    wb_update_dr_i;
  logic                    wb_capture_dr_i;

  // Instructions
  logic                    wb_debug_select_i;

  // WISHBONE Master Interface Signals
  logic                    wb_clk_i;

  logic                    wb_cyc_o;
  logic                    wb_stb_o;
  logic [             2:0] wb_cti_o;
  logic [             1:0] wb_bte_o;
  logic                    wb_we_o;
  logic [ADDR_WIDTH  -1:0] wb_adr_o;
  logic [DATA_WIDTH/8-1:0] wb_sel_o;
  logic [DATA_WIDTH  -1:0] wb_dat_o;
  logic [DATA_WIDTH  -1:0] wb_dat_i;
  logic                    wb_ack_i;
  logic                    wb_err_i;

  // WISHBONE Target Interface Signals (JTAG Serial Port)
  logic                    wb_jsp_clk_i;
  logic                    wb_jsp_rst_i;
  logic                    wb_jsp_cyc_i;
  logic                    wb_jsp_stb_i;
  logic                    wb_jsp_we_i;
  logic [             2:0] wb_jsp_adr_i;
  logic [             7:0] wb_jsp_dat_o;
  logic [             7:0] wb_jsp_dat_i;
  logic                    wb_jsp_ack_o;
  logic                    wb_jsp_err_o;

  logic                   jsp_int_o;

  //CPU/Thread debug ports
  logic                                                               wb_cpu_clk_i;
  logic                                                               wb_cpu_rstn_i;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_ADDR_WIDTH-1:0] wb_cpu_addr_o;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] wb_cpu_data_i;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] wb_cpu_data_o;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     wb_cpu_bp_i;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     wb_cpu_stall_o;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     wb_cpu_stb_o;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     wb_cpu_we_o;
  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     wb_cpu_ack_i;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  //DUT WB
  mpsoc_dbg_top_wb #(
    .X ( X ),
    .Y ( Y ),
    .Z ( Z ),

    .CORES_PER_TILE ( CORES_PER_TILE ),

    .ADDR_WIDTH ( ADDR_WIDTH ),
    .DATA_WIDTH ( DATA_WIDTH ),

    .CPU_ADDR_WIDTH ( CPU_ADDR_WIDTH ),
    .CPU_DATA_WIDTH ( CPU_DATA_WIDTH ),

    .DATAREG_LEN ( DATAREG_LEN )
  )
  top_wb (
    // JTAG signals
    .tck_i ( wb_tck_i ),
    .tdi_i ( wb_tdi_i ),
    .tdo_o ( wb_tdo_o ),

    // TAP states
    .tlr_i        ( wb_tlr_i        ),
    .shift_dr_i   ( wb_shift_dr_i   ),
    .pause_dr_i   ( wb_pause_dr_i   ),
    .update_dr_i  ( wb_update_dr_i  ),
    .capture_dr_i ( wb_capture_dr_i ),

    // Instructions
    .debug_select_i ( wb_debug_select_i ),

    // WISHBONE Master Interface Signals
    .wb_clk_i ( wb_clk_i ),

    .wb_cyc_o ( wb_clk_i ),
    .wb_stb_o ( wb_stb_o ),
    .wb_cti_o ( wb_cti_o ),
    .wb_bte_o ( wb_bte_o ),
    .wb_we_o  ( wb_we_o  ),
    .wb_adr_o ( wb_adr_o ),
    .wb_sel_o ( wb_sel_o ),
    .wb_dat_o ( wb_dat_o ),
    .wb_dat_i ( wb_dat_i ),
    .wb_ack_i ( wb_ack_i ),
    .wb_err_i ( wb_err_i ),

    // WISHBONE Target Interface Signals (JTAG Serial Port)
    .wb_jsp_clk_i ( wb_jsp_clk_i ),
    .wb_jsp_rst_i ( wb_jsp_rst_i ),
    .wb_jsp_cyc_i ( wb_jsp_cyc_i ),
    .wb_jsp_stb_i ( wb_jsp_stb_i ),
    .wb_jsp_we_i  ( wb_jsp_we_i  ),
    .wb_jsp_adr_i ( wb_jsp_adr_i ),
    .wb_jsp_dat_o ( wb_jsp_dat_o ),
    .wb_jsp_dat_i ( wb_jsp_dat_i ),
    .wb_jsp_ack_o ( wb_jsp_ack_o ),
    .wb_jsp_err_o ( wb_jsp_err_o ),

    .jsp_int_o ( jsp_int_o ),

    //CPU/Thread debug ports
    .cpu_clk_i   ( wb_cpu_clk_i   ),
    .cpu_rstn_i  ( wb_cpu_rstn_i  ),
    .cpu_addr_o  ( wb_cpu_addr_o  ),
    .cpu_data_i  ( wb_cpu_data_i  ),
    .cpu_data_o  ( wb_cpu_data_o  ),
    .cpu_bp_i    ( wb_cpu_bp_i    ),
    .cpu_stall_o ( wb_cpu_stall_o ),
    .cpu_stb_o   ( wb_cpu_stb_o   ),
    .cpu_we_o    ( wb_cpu_we_o    ),
    .cpu_ack_i   ( wb_cpu_ack_i   )
  );
endmodule
