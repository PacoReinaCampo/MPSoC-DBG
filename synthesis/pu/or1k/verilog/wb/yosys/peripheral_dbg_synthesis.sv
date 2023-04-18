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
//              Master Slave Interface Tesbench                               //
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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

`include "peripheral_dbg_pu_or1k_defines.sv"

module peripheral_dbg_synthesis #(
  parameter DBG_WISHBONE_SUPPORTED = "ENABLED",
  parameter DBG_CPU0_SUPPORTED     = "ENABLED",
  parameter DBG_CPU1_SUPPORTED     = "NONE",
  // To include the JTAG Serial Port (JSP)
  parameter DBG_JSP_SUPPORTED      = "ENABLED",
  // Define this if you intend to use the JSP in a system with multiple
  // devices on the JTAG chain
  parameter ADBG_JSP_SUPPORT_MULTI = "ENABLED",
  // If this is enabled, status bits will be skipped on burst
  // reads and writes to improve download speeds.
  parameter ADBG_USE_HISPEED       = "ENABLED"
) (
  input         wb_clk_i,
  input         wb_rst_i,
  output [31:0] wb_adr_o,
  output [31:0] wb_dat_o,
  input  [31:0] wb_dat_i,
  output        wb_cyc_o,
  output        wb_stb_o,
  output [ 3:0] wb_sel_o,
  output        wb_we_o,
  input         wb_ack_i,
  output        wb_cab_o,
  input         wb_err_i,
  output [ 2:0] wb_cti_o,
  output [ 1:0] wb_bte_o
);

  //////////////////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // JTAG signals
  logic      tck_i;
  logic      tdi_i;
  logic      tdo_o;
  logic      rst_i;

  // TAP states
  logic shift_dr_i;
  logic pause_dr_i;
  logic update_dr_i;
  logic capture_dr_i;

  // Module select from TAP
  logic debug_select_i;

  // CPU signals
  logic         cpu0_clk_i;
  logic  [31:0] cpu0_addr_o;
  logic  [31:0] cpu0_data_i;
  logic  [31:0] cpu0_data_o;
  logic         cpu0_bp_i;
  logic         cpu0_stall_o;
  logic         cpu0_stb_o;
  logic         cpu0_we_o;
  logic         cpu0_ack_i;
  logic         cpu0_rst_o;

  logic         cpu1_clk_i;
  logic  [31:0] cpu1_addr_o;
  logic  [31:0] cpu1_data_i;
  logic  [31:0] cpu1_data_o;
  logic         cpu1_bp_i;
  logic         cpu1_stall_o;
  logic         cpu1_stb_o;
  logic         cpu1_we_o;
  logic         cpu1_ack_i;
  logic         cpu1_rst_o;

  logic  [31:0] wb_jsp_adr_i;
  logic  [31:0] wb_jsp_dat_o;
  logic  [31:0] wb_jsp_dat_i;
  logic         wb_jsp_cyc_i;
  logic         wb_jsp_stb_i;
  logic  [ 3:0] wb_jsp_sel_i;
  logic         wb_jsp_we_i;
  logic         wb_jsp_ack_o;
  logic         wb_jsp_cab_i;
  logic         wb_jsp_err_o;
  logic  [ 2:0] wb_jsp_cti_i;
  logic  [ 1:0] wb_jsp_bte_i;
  logic         int_o;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  // DUT WB
  peripheral_dbg_pu_or1k_top #(
    .DBG_WISHBONE_SUPPORTED(DBG_WISHBONE_SUPPORTED),
    .DBG_CPU0_SUPPORTED    (DBG_CPU0_SUPPORTED),
    .DBG_CPU1_SUPPORTED    (DBG_CPU1_SUPPORTED),
    // To include the JTAG Serial Port (JSP)
    .DBG_JSP_SUPPORTED     (DBG_JSP_SUPPORTED),
    // Define this if you intend to use the JSP in a system with multiple
    // devices on the JTAG chain
    .ADBG_JSP_SUPPORT_MULTI(ADBG_JSP_SUPPORT_MULTI),
    // If this is enabled, status bits will be skipped on burst
    // reads and writes to improve download speeds.
    .ADBG_USE_HISPEED      (ADBG_USE_HISPEED)
  ) dbg_pu_or1k_top (
    // JTAG signals
    .tck_i(tck_i),
    .tdi_i(tdi_i),
    .tdo_o(tdo_o),
    .rst_i(rst_i),

    // TAP states
    .shift_dr_i  (shift_dr_i),
    .pause_dr_i  (pause_dr_i),
    .update_dr_i (update_dr_i),
    .capture_dr_i(capture_dr_i),

    // Module select from TAP
    .debug_select_i(debug_select_i),

    .wb_clk_i(wb_clk_i),
    .wb_rst_i(wb_rst_i),
    .wb_adr_o(wb_adr_o),
    .wb_dat_o(wb_dat_o),
    .wb_dat_i(wb_dat_i),
    .wb_cyc_o(wb_cyc_o),
    .wb_stb_o(wb_stb_o),
    .wb_sel_o(wb_sel_o),
    .wb_we_o (wb_we_o ),
    .wb_ack_i(wb_ack_i),
    .wb_cab_o(wb_cab_o),
    .wb_err_i(wb_err_i),
    .wb_cti_o(wb_cti_o),
    .wb_bte_o(wb_bte_o),
	
    // CPU signals
    .cpu0_clk_i  (cpu0_clk_i  ),
    .cpu0_addr_o (cpu0_addr_o ),
    .cpu0_data_i (cpu0_data_i ),
    .cpu0_data_o (cpu0_data_o ),
    .cpu0_bp_i   (cpu0_bp_i   ),
    .cpu0_stall_o(cpu0_stall_o),
    .cpu0_stb_o  (cpu0_stb_o  ),
    .cpu0_we_o   (cpu0_we_o   ),
    .cpu0_ack_i  (cpu0_ack_i  ),
    .cpu0_rst_o  (cpu0_rst_o  ),
	
    .cpu1_clk_i  (cpu1_clk_i  ),
    .cpu1_addr_o (cpu1_addr_o ),
    .cpu1_data_i (cpu1_data_i ),
    .cpu1_data_o (cpu1_data_o ),
    .cpu1_bp_i   (cpu1_bp_i   ),
    .cpu1_stall_o(cpu1_stall_o),
    .cpu1_stb_o  (cpu1_stb_o  ),
    .cpu1_we_o   (cpu1_we_o   ),
    .cpu1_ack_i  (cpu1_ack_i  ),
    .cpu1_rst_o  (cpu1_rst_o  ),
	
    .wb_jsp_adr_i(wb_jsp_adr_i),
    .wb_jsp_dat_o(wb_jsp_dat_o),
    .wb_jsp_dat_i(wb_jsp_dat_i),
    .wb_jsp_cyc_i(wb_jsp_cyc_i),
    .wb_jsp_stb_i(wb_jsp_stb_i),
    .wb_jsp_sel_i(wb_jsp_sel_i),
    .wb_jsp_we_i (wb_jsp_we_i ),
    .wb_jsp_ack_o(wb_jsp_ack_o),
    .wb_jsp_cab_i(wb_jsp_cab_i),
    .wb_jsp_err_o(wb_jsp_err_o),
    .wb_jsp_cti_i(wb_jsp_cti_i),
    .wb_jsp_bte_i(wb_jsp_bte_i),
    .int_o       (int_o       )
  );
endmodule
