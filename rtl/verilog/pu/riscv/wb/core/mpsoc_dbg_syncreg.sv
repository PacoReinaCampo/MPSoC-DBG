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
module mpsoc_dbg_syncreg (
  input        CLKA,
  input        CLKB,
  input        RST,
  input  [3:0] DATA_IN,
  output [3:0] DATA_OUT
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg [3:0] regA;
  reg [3:0] regB;
  reg 	    strobe_toggle;
  reg 	    ack_toggle;

  wire       a_not_equal;
  wire       a_enable;
  wire       strobe_sff_out;
  wire       ack_sff_out;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Combinatorial assignments
  assign a_enable    = a_not_equal & ack_sff_out;
  assign a_not_equal = !(DATA_IN == regA);
  assign DATA_OUT    = regB;   

  // register A (latches input any time it changes)
  always @ (posedge CLKA or posedge RST) begin
    if(RST) begin
      regA <= 4'b0;
    end
    else if(a_enable) begin
      regA <= DATA_IN;
    end
  end

  // register B (latches data from regA when enabled by the strobe SFF)
  always @ (posedge CLKB or posedge RST) begin
    if(RST) begin
      regB <= 4'b0;
    end
    else if(strobe_sff_out) begin
      regB <= regA;
    end
  end

  // 'strobe' toggle FF
  always @ (posedge CLKA or posedge RST) begin
    if(RST) begin
      strobe_toggle <= 1'b0;
    end
      else if(a_enable) begin
        strobe_toggle <= ~strobe_toggle;
    end
  end

  // 'ack' toggle FF
  // This is set to '1' at reset, to initialize the unit.
  always @ (posedge CLKB or posedge RST) begin
    if(RST) begin
      ack_toggle <= 1'b1;
    end
    else if (strobe_sff_out) begin
      ack_toggle <= ~ack_toggle;
    end
  end

  // 'strobe' sync element
  mpsoc_dbg_syncflop strobe_sff (
    .DEST_CLK  (CLKB),
    .D_SET     (1'b0),
    .D_RST     (strobe_sff_out),
    .RESET     (RST),
    .TOGGLE_IN (strobe_toggle),
    .D_OUT     (strobe_sff_out)
  );

  // 'ack' sync element
  mpsoc_dbg_syncflop ack_sff (
    .DEST_CLK  (CLKA),
    .D_SET     (1'b0),
    .D_RST     (a_enable),
    .RESET     (RST),
    .TOGGLE_IN (ack_toggle),
    .D_OUT     (ack_sff_out)
  );  
endmodule
