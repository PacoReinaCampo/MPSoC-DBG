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

`include "mpsoc_dbg_pkg.sv"

// Top module
module mpsoc_dbg_top_wb #(
  parameter X              = 2,
  parameter Y              = 2,
  parameter Z              = 2,
  parameter CORES_PER_TILE = 1,
  parameter ADDR_WIDTH     = 32,
  parameter DATA_WIDTH     = 32,
  parameter CPU_ADDR_WIDTH = 32,
  parameter CPU_DATA_WIDTH = 32,
  parameter DATAREG_LEN    = 64
)
  (
    // JTAG signals
    input                     tck_i,
    input                     tdi_i,
    output reg                tdo_o,

    // TAP states
    input                     tlr_i,       //TestLogicReset
    input                     shift_dr_i,
    input                     pause_dr_i,
    input                     update_dr_i,
    input                     capture_dr_i,

    // Instructions
    input                     debug_select_i,

    // WISHBONE Master Interface Signals
    input                     wb_clk_i,

    output                    wb_cyc_o,
    output                    wb_stb_o,
    output [             2:0] wb_cti_o,
    output [             1:0] wb_bte_o,
    output                    wb_we_o,
    output [ADDR_WIDTH  -1:0] wb_adr_o,
    output [DATA_WIDTH/8-1:0] wb_sel_o,
    output [DATA_WIDTH  -1:0] wb_dat_o,
    input  [DATA_WIDTH  -1:0] wb_dat_i,
    input                     wb_ack_i,
    input                     wb_err_i,

    // WISHBONE Target Interface Signals (JTAG Serial Port)
    input                     wb_jsp_clk_i,
    input                     wb_jsp_rst_i,
    input                     wb_jsp_cyc_i,
    input                     wb_jsp_stb_i,
    input                     wb_jsp_we_i,
    input  [             2:0] wb_jsp_adr_i,
    output [             7:0] wb_jsp_dat_o,
    input  [             7:0] wb_jsp_dat_i,
    output                    wb_jsp_ack_o,
    output                    wb_jsp_err_o,
    output                       jsp_int_o,

    //CPU/Thread debug ports
    input                                                                cpu_clk_i,
    input                                                                cpu_rstn_i,
    output [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_ADDR_WIDTH-1:0] cpu_addr_o,
    input  [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] cpu_data_i,
    output [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] cpu_data_o,
    input  [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_bp_i,
    output [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_stall_o,
    output [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_stb_o,
    output [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_we_o,
    input  [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_ack_i
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic tdo_busif;
  logic tdo_cpu;
  logic tdo_jsp;

  // Registers
  reg  [`DBG_TOP_DATAREG_LEN     -1:0] input_shift_reg; // Main chain shift register, pushed into each module
  reg  [`DBG_TOP_MODULE_ID_LENGTH-1:0] module_id_reg;   // Module selection register

  // Control signals
  wire                                 select_cmd;      // True when the command (registered at Update_DR) is for top level/module selection
  wire [`DBG_TOP_MODULE_ID_LENGTH-1:0] module_id_in;    // The part of the input_shift_register to be used as the module select data
  reg  [`DBG_TOP_MAX_MODULES     -1:0] module_selects;  // Select signals for the individual modules, number of modules = 4 (CPU, JSP, Bus, reserved)
  wire                                 select_inhibit;  // OR of inhibit signals from sub-modules, prevents latching of a new module ID
  wire [`DBG_TOP_MAX_MODULES     -1:0] module_inhibit;  // signals to allow submodules to prevent top level from latching new module ID

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Combinatorial assignments
  assign select_cmd   = input_shift_reg[`DBG_TOP_DATAREG_LEN-1];
  assign module_id_in = input_shift_reg[`DBG_TOP_DATAREG_LEN-2 -: `DBG_TOP_MODULE_ID_LENGTH];

  // Module select register and select signals
  always @(posedge tck_i, posedge tlr_i) begin
    if (tlr_i) begin
      module_id_reg <= 'h0;
    end
    else if (debug_select_i && select_cmd && update_dr_i && !select_inhibit) begin  // Chain select
      module_id_reg <= module_id_in;
    end
  end

  always @(*) begin
    module_selects                = 'h0;
    module_selects[module_id_reg] = 1'b1;
  end

  // Data input shift register
  always @ (posedge tck_i, posedge tlr_i) begin
    if      ( tlr_i                       ) input_shift_reg <= 'h0;
    else if ( debug_select_i && shift_dr_i) input_shift_reg <= {tdi_i, input_shift_reg[`DBG_TOP_DATAREG_LEN-1:1]};
  end

  //Wishbone debug module instantiation
  mpsoc_dbg_wb_module #(
    .ADDR_WIDTH  ( ADDR_WIDTH  ),
    .DATA_WIDTH  ( DATA_WIDTH  )
  )
  i_dbg_wb (
    // JTAG signals
    .tlr_i            ( tlr_i        ),
    .tck_i            ( tck_i        ),
    .module_tdo_o     ( tdo_busif    ),
    .tdi_i            ( tdi_i        ),

    // TAP states
    .capture_dr_i     ( capture_dr_i ),
    .shift_dr_i       ( shift_dr_i   ),
    .update_dr_i      ( update_dr_i  ),

    .data_register_i  ( input_shift_reg[`DBG_TOP_DATAREG_LEN-1 -: `DBG_WB_DATAREG_LEN]),
    .module_select_i  ( module_selects [`DBG_TOP_BUSIF_DEBUG_MODULE] ),
    .top_inhibit_o    ( module_inhibit [`DBG_TOP_BUSIF_DEBUG_MODULE] ),

    // WISHBONE common signals
    .wb_clk_i         ( wb_clk_i ),

    // WISHBONE master interface
    .wb_adr_o         ( wb_adr_o ), 
    .wb_dat_o         ( wb_dat_o ),
    .wb_dat_i         ( wb_dat_i ),
    .wb_cyc_o         ( wb_cyc_o ),
    .wb_stb_o         ( wb_stb_o ),
    .wb_sel_o         ( wb_sel_o ),
    .wb_we_o          ( wb_we_o  ),
    .wb_ack_i         ( wb_ack_i ),
    .wb_err_i         ( wb_err_i ),
    .wb_cti_o         ( wb_cti_o ),
    .wb_bte_o         ( wb_bte_o )
  );

  mpsoc_dbg_or1k_module #(
    .X              ( X ),
    .Y              ( Y ),
    .Z              ( Z ),
    .CORES_PER_TILE ( CORES_PER_TILE )
  )
  i_dbg_cpu_or1k (
    // JTAG signals
    .tck_i           ( tck_i        ),
    .module_tdo_o    ( tdo_cpu      ),
    .tdi_i           ( tdi_i        ),

    // TAP states
    .tlr_i           ( tlr_i        ),
    .capture_dr_i    ( capture_dr_i ),
    .shift_dr_i      ( shift_dr_i   ),
    .update_dr_i     ( update_dr_i  ),

    .data_register_i ( input_shift_reg[`DBG_TOP_DATAREG_LEN-1 -: `DBG_OR1K_DATAREG_LEN]),
    .module_select_i ( module_selects [`DBG_TOP_CPU_DEBUG_MODULE]),
    .top_inhibit_o   ( module_inhibit [`DBG_TOP_CPU_DEBUG_MODULE]),

    // CPU signals
    .cpu_rstn_i      ( cpu_rstn_i  ),
    .cpu_clk_i       ( cpu_clk_i   ), 
    .cpu_addr_o      ( cpu_addr_o  ), 
    .cpu_data_i      ( cpu_data_i  ), 
    .cpu_data_o      ( cpu_data_o  ),
    .cpu_bp_i        ( cpu_bp_i    ),
    .cpu_stall_o     ( cpu_stall_o ),
    .cpu_stb_o       ( cpu_stb_o   ),
    .cpu_we_o        ( cpu_we_o    ),
    .cpu_ack_i       ( cpu_ack_i   )
  );

  mpsoc_dbg_jsp_wb_module i_dbg_jsp (
    .rst_i            ( tlr_i),

    // JTAG signals
    .tck_i            ( tck_i),
    .module_tdo_o     ( tdo_jsp),
    .tdi_i            ( tdi_i),

    // TAP states
    .capture_dr_i     ( capture_dr_i),
    .shift_dr_i       ( shift_dr_i),
    .update_dr_i      ( update_dr_i),

    .data_register_i  ( input_shift_reg[`DBG_TOP_DATAREG_LEN-1 -: `DBG_JSP_DATAREG_LEN]),
    .module_select_i  ( module_selects [`DBG_TOP_JSP_DEBUG_MODULE]),
    .top_inhibit_o    ( module_inhibit [`DBG_TOP_JSP_DEBUG_MODULE]),

    // WISHBONE connections
    .wb_clk_i         ( wb_jsp_clk_i ),
    .wb_rst_i         ( wb_jsp_rst_i ),
    .wb_cyc_i         ( wb_jsp_cyc_i ),
    .wb_stb_i         ( wb_jsp_stb_i ),
    .wb_we_i          ( wb_jsp_we_i  ),
    .wb_adr_i         ( wb_jsp_adr_i ),
    .wb_dat_i         ( wb_jsp_dat_i ),
    .wb_dat_o         ( wb_jsp_dat_o ),
    .wb_ack_o         ( wb_jsp_ack_o ),
    .wb_err_o         ( wb_jsp_err_o ),
    .int_o            (    jsp_int_o )
  );

  assign module_inhibit[`DBG_TOP_RESERVED_DBG_MODULE] = 1'b0;

  assign select_inhibit = |module_inhibit;

  // TDO output MUX
  always @(*) begin
    case (module_id_reg)
      `DBG_TOP_BUSIF_DEBUG_MODULE: tdo_o = tdo_busif;
      `DBG_TOP_CPU_DEBUG_MODULE  : tdo_o = tdo_cpu;
      `DBG_TOP_JSP_DEBUG_MODULE  : tdo_o = tdo_jsp;
      default                    : tdo_o = 1'b0;
    endcase
  end
endmodule
