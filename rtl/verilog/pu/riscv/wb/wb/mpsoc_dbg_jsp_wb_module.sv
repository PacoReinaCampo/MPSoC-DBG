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
 *   Nathan Yawn <nathan.yawn@opencores.org>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

// Module interface
module mpsoc_dbg_jsp_wb_module #(
  parameter DBG_JSP_DATAREG_LEN = 64
)
  (
    input                           rst_i,

    // JTAG signals
    input                           tck_i,
    input                           tdi_i,
    output                          module_tdo_o,

  // TAP states
    input                           capture_dr_i,
    input                           shift_dr_i,
    input                           update_dr_i,

    input [DBG_JSP_DATAREG_LEN-1:0] data_register_i,  // the data register is at top level, shared between all modules
    input                           module_select_i,
    output                          top_inhibit_o,

    // WISHBONE slave interface
    input                           wb_clk_i,
    input                           wb_rst_i,
    input                           wb_cyc_i,
    input                           wb_stb_i,
    input                           wb_we_i,
    input  [                   2:0] wb_adr_i,
    input  [                   7:0] wb_dat_i,
    output [                   7:0] wb_dat_o,
    output                          wb_ack_o,
    output                          wb_err_o,
    output                          int_o 
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic       biu_clk;
  logic       biu_rst;
  logic [7:0] biu_di;
  logic [7:0] biu_do;
  logic [3:0] biu_bytes_available;
  logic [3:0] biu_space_available;
  logic       biu_rd_strobe;
  logic       biu_wr_strobe;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  //Hookup JSP Debug Core
  mpsoc_dbg_jsp_module_core #(
    .DBG_JSP_DATAREG_LEN ( DBG_JSP_DATAREG_LEN )
  )
  jsp_core_inst (
    .rst_i ( rst_i ),

    // JTAG signals
    .tck_i        ( tck_i        ),
    .tdi_i        ( tdi_i        ),
    .module_tdo_o ( module_tdo_o ),

    // TAP states
    .capture_dr_i ( capture_dr_i ),
    .shift_dr_i   ( shift_dr_i   ),
    .update_dr_i  ( update_dr_i  ),

    .data_register_i ( data_register_i ),  // the data register is at top level, shared between all modules
    .module_select_i ( module_select_i ),
    .top_inhibit_o   ( top_inhibit_o   ),

    // JSP BIU interface
    .biu_clk             ( biu_clk             ),
    .biu_rst             ( biu_rst             ),
    .biu_di              ( biu_di              ),  // data towards BIU
    .biu_do              ( biu_do              ),  // data from BIU
    .biu_space_available ( biu_space_available ),
    .biu_bytes_available ( biu_bytes_available ),
    .biu_rd_strobe       ( biu_rd_strobe       ),  // Indicates that the BIU should ACK last read operation + start another
    .biu_wr_strobe       ( biu_wr_strobe       )   // Indicates BIU should latch input + begin a write operation
  );

  //Hookup JSP Wishbone Interface
  mpsoc_dbg_jsp_wb_biu jsp_biu_inst (
    // Debug interface signals
    .tck_i             ( biu_clk             ),
    .rst_i             ( biu_rst             ),
    .data_i            ( biu_di              ),
    .data_o            ( biu_do              ),
    .bytes_available_o ( biu_bytes_available ),
    .bytes_free_o      ( biu_space_available ),
    .rd_strobe_i       ( biu_rd_strobe       ),
    .wr_strobe_i       ( biu_wr_strobe       ),

    // Wishbone slave signals
    .wb_clk_i ( wb_clk_i ),
    .wb_rst_i ( wb_rst_i ),
    .wb_cyc_i ( wb_cyc_i ),
    .wb_stb_i ( wb_stb_i ),
    .wb_we_i  ( wb_we_i  ),
    .wb_adr_i ( wb_adr_i ),
    .wb_dat_i ( wb_dat_i ),
    .wb_dat_o ( wb_dat_o ),
    .wb_ack_o ( wb_ack_o ),
    .wb_err_o ( wb_err_o ),

    .int_o ( int_o )
  );
endmodule
