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
//              PU-OR1K                                                       //
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

`include "adbg_or1k_defines.sv"

module adbg_or1k_status_reg (
  input [`DBG_OR1K_STATUS_LEN - 1:0] data_i,

  input           we_i,
  input           tck_i,
  input           bp_i,
  input           rst_i,
  input           cpu_clk_i,

  output          cpu_stall_o,
  output reg      cpu_rst_o ,

  output [`DBG_OR1K_STATUS_LEN - 1:0] ctrl_reg_o
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  reg            cpu_reset;
  wire [2:1]     cpu_op_out;

  reg            stall_bp, stall_bp_csff, stall_bp_tck;
  reg            stall_reg, stall_reg_csff, stall_reg_cpu;
  reg            cpu_reset_csff;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Breakpoint is latched and synchronized. Stall is set and latched.
  // This is done in the CPU clock domain, because the JTAG clock (TCK) is
  // irregular.  By only allowing bp_i to set (but not reset) the stall_bp
  // signal, we insure that the CPU will remain in the stalled state until
  // the debug host can read the state.
  always @ (posedge cpu_clk_i or posedge rst_i) begin
    if(rst_i)
      stall_bp <= 1'b0;
    else if(bp_i)
      stall_bp <= 1'b1;
    else if(stall_reg_cpu)
      stall_bp <= 1'b0;
  end

  // Synchronizing
  always @ (posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      stall_bp_csff <= 1'b0;
      stall_bp_tck  <= 1'b0;
    end
    else begin
      stall_bp_csff <= stall_bp;
      stall_bp_tck  <= stall_bp_csff;
    end
  end

  always @ (posedge cpu_clk_i or posedge rst_i) begin
    if (rst_i) begin
      stall_reg_csff <= 1'b0;
      stall_reg_cpu  <= 1'b0;
    end
    else begin
      stall_reg_csff <= stall_reg;
      stall_reg_cpu  <= stall_reg_csff;
    end
  end

  // bp_i forces a stall immediately on a breakpoint
  // stall_bp holds the stall until the debug host acts
  // stall_reg_cpu allows the debug host to control a stall.
  assign cpu_stall_o = bp_i | stall_bp | stall_reg_cpu;

  // Writing data to the control registers (stall)
  // This can be set either by the debug host, or by
  // a CPU breakpoint.  It can only be cleared by the host.
  always @ (posedge tck_i or posedge rst_i) begin
    if (rst_i)
      stall_reg <= 1'b0;
    else if (stall_bp_tck)
      stall_reg <= 1'b1;
    else if (we_i)
      stall_reg <= data_i[0];
  end

  // Writing data to the control registers (reset)
  always @ (posedge tck_i or posedge rst_i) begin
    if (rst_i)
      cpu_reset  <= 1'b0;
    else if(we_i)
      cpu_reset  <= data_i[1];
  end

  // Synchronizing signals from registers
  always @ (posedge cpu_clk_i or posedge rst_i) begin
    if (rst_i) begin
      cpu_reset_csff      <= 1'b0; 
      cpu_rst_o           <= 1'b0; 
    end
    else begin
      cpu_reset_csff      <= cpu_reset;
      cpu_rst_o           <= cpu_reset_csff;
    end
  end

  // Value for read back
  assign ctrl_reg_o = {cpu_reset, stall_reg};
endmodule
