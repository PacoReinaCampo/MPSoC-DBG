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

module adbg_syncflop (
  input   DEST_CLK,
  input   D_SET,
  input   D_RST,
  input   RESET,
  input   TOGGLE_IN,
  output  D_OUT
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  reg     sync1;
  reg     sync2;
  reg     syncprev;
  reg     srflop;

  wire    syncxor;
  wire    srinput;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Combinatorial assignments
  assign  syncxor = sync2 ^ syncprev;
  assign  srinput = syncxor | D_SET;  
  assign  D_OUT = srflop | syncxor;

  // First DFF (always enabled)
  always @ (posedge DEST_CLK or posedge RESET) begin
    if(RESET) sync1 <= 1'b0;
    else sync1 <= TOGGLE_IN;
  end

  // Second DFF (always enabled)
  always @ (posedge DEST_CLK or posedge RESET) begin
    if(RESET) sync2 <= 1'b0;
    else sync2 <= sync1;
  end

  // Third DFF (always enabled, used to detect toggles)
  always @ (posedge DEST_CLK or posedge RESET) begin
    if(RESET) syncprev <= 1'b0;
    else syncprev <= sync2;
  end

  // Set/Reset FF (holds detected toggles)
  always @ (posedge DEST_CLK or posedge RESET) begin
    if(RESET)         srflop <= 1'b0;
    else if(D_RST)    srflop <= 1'b0;
    else if (srinput) srflop <= 1'b1;
  end
endmodule
