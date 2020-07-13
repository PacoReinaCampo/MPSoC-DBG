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

// Top module
module mpsoc_dbg_syncflop (
  input  RESET,     // asynchronous reset

  input  DEST_CLK,  // destination clock domain clock
  input  D_SET,     // synchronously set output to '1' (synchronous to dest.clock domain)
  input  D_RST,     // synchronously reset output to '0' (synch. to dest.clock domain)
  input  TOGGLE_IN, // toggle data from source clock domain
  output D_OUT      // output (synch. to dest.clock domain)
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg sync1, sync2, syncprev;
  reg srflop;

  // Combinatorial assignments
  wire toggle;
  wire srinput;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Synchronise toggle signal to destination clock domain

  // First synchronisation stage
  always @(posedge DEST_CLK,posedge RESET) begin
    if (RESET) sync1 <= 1'b0;
    else       sync1 <= TOGGLE_IN;
  end

  // Second synchronisation stage
  always @ (posedge DEST_CLK or posedge RESET) begin
    if (RESET) sync2 <= 1'b0;
    else       sync2 <= sync1;
  end

  // Detect toggle

  // Previous synchronized value
  always @ (posedge DEST_CLK or posedge RESET) begin
    if (RESET) syncprev <= 1'b0;
    else       syncprev <= sync2;
  end

  // Combinatorial assignments
  assign toggle  = sync2 ^ syncprev;
  assign srinput = toggle | D_SET;

  assign D_OUT   = toggle | srflop;

  // Set/Reset FF (holds detected toggles)
  always @ (posedge DEST_CLK or posedge RESET) begin
    if      (RESET  ) srflop <= 1'b0;
    else if (D_RST  ) srflop <= 1'b0;
    else if (srinput) srflop <= 1'b1;
  end
endmodule
