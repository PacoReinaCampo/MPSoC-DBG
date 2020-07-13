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
 *   Nathan Yawn <nathan.yawn@opencores.org>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

module mpsoc_dbg_or1k_status_reg  #(
  parameter X              = 2,
  parameter Y              = 2,
  parameter Z              = 2,
  parameter CORES_PER_TILE = 1
)
  (
    input                                                  tlr_i,
    input                                                  tck_i,
    input                                                  we_i,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] ctrl_reg_o,

    input                                                  cpu_rstn_i,
    input                                                  cpu_clk_i,
    input  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] data_i,
    input  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] bp_i,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] cpu_stall_o
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg   [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] stall_bp, stall_bp_csff, stall_bp_tck;
  reg   [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] stall_reg, stall_reg_csff, stall_reg_cpu;

  genvar i,j,k,t;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Breakpoint is latched and synchronized. Stall is set and latched.
  // This is done in the CPU clock domain, because the JTAG clock (TCK) is
  // irregular.  By only allowing bp_i to set (but not reset) the stall_bp
  // signal, we insure that the CPU will remain in the stalled state until
  // the debug host can read the state.

  generate
    for (i=0;i<X;i=i+1) begin
      for (j=0;j<Y;j=j+1) begin
        for (k=0;k<Z;k=k+1) begin
          for (t=0;t<CORES_PER_TILE;t=t+1) begin
            always @(posedge cpu_clk_i,negedge cpu_rstn_i) begin
              if        (!cpu_rstn_i                ) stall_bp [i][j][k][t] <= 1'b0;
              else begin
                if      (bp_i          [i][j][k][t] ) stall_bp [i][j][k][t] <= 1'b1;
                else if (stall_reg_cpu [i][j][k][t] ) stall_bp [i][j][k][t] <= 1'b0;
              end
            end
          end
        end
      end
    end
  endgenerate

  // Synchronizing
  always @(posedge tck_i,posedge tlr_i) begin
    if (tlr_i) begin
      stall_bp_csff <= 'h0;
      stall_bp_tck  <= 'h0;
    end
    else begin
      stall_bp_csff <= stall_bp;
      stall_bp_tck  <= stall_bp_csff;
    end
  end

  always @(posedge cpu_clk_i,negedge cpu_rstn_i) begin
    if (!cpu_rstn_i) begin
      stall_reg_csff <= 'h0;
      stall_reg_cpu  <= 'h0;
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
  generate
    for (i=0;i<X;i=i+1) begin
      for (j=0;j<Y;j=j+1) begin
        for (k=0;k<Z;k=k+1) begin
          for (t=0;t<CORES_PER_TILE;t=t+1) begin
            always @(posedge tck_i,posedge tlr_i) begin
              if        (tlr_i                     ) stall_reg [i][j][k][t] <= 1'b0;
              else begin
                if      (stall_bp_tck [i][j][k][t] ) stall_reg [i][j][k][t] <= 1'b1;
                else if (we_i                      ) stall_reg [i][j][k][t] <= data_i[i][j][k][t];
              end
            end
          end
        end
      end
    end
  endgenerate

  // Value for read back
  assign ctrl_reg_o = stall_reg;
endmodule
