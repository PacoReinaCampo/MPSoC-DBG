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
module mpsoc_dbg_bytefifo (
  input            CLK,
  input            RST,
  input      [7:0] DATA_IN,
  output reg [7:0] DATA_OUT,
  input            PUSH_POPn,
  input            EN,
  output     [3:0] BYTES_AVAIL,
  output     [3:0] BYTES_FREE
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  reg [7:0] reg0, reg1, reg2, reg3, reg4, reg5, reg6, reg7;
  reg [3:0] counter;

  wire       push_ok;
  wire       pop_ok;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Combinatorial assignments
  assign BYTES_AVAIL = counter;  
  assign BYTES_FREE  = 4'h8 - BYTES_AVAIL;
  assign push_ok     = !(counter == 4'h8);
  assign pop_ok      = !(counter == 4'h0);

  // FIFO memory / shift registers

  // Reg 0 - takes input from DATA_IN
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg0 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg0 <= DATA_IN;
    end
  end

  // Reg 1 - takes input from reg0
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg1 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg1 <= reg0;
    end
  end

  // Reg 2 - takes input from reg1
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg2 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg2 <= reg1;
    end
  end

  // Reg 3 - takes input from reg2
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg3 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg3 <= reg2;
    end
  end

  // Reg 4 - takes input from reg3
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg4 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg4 <= reg3;
    end
  end

  // Reg 5 - takes input from reg4
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg5 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg5 <= reg4;
    end
  end

  // Reg 6 - takes input from reg5
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg6 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg6 <= reg5;
    end
  end

  // Reg 7 - takes input from reg6
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      reg7 <= 8'h0;
    end
    else if(EN & PUSH_POPn & push_ok) begin
      reg7 <= reg6;
    end
  end

  // Read counter
  // This is a 4-bit saturating up/down counter
  // The 'saturating' is done via push_ok and pop_ok
  always @ (posedge CLK or posedge RST) begin
    if(RST) begin
      counter <= 4'h0;
    end
    else if (EN &  PUSH_POPn & push_ok) begin
      counter <= counter + 4'h1;
    end
    else if (EN & ~PUSH_POPn & pop_ok) begin
      counter <= counter - 4'h1;
    end
  end

  // Output decoder
  always @ (counter or reg0 or reg1 or reg2
                    or reg3 or reg4 or reg5
                    or reg6 or reg7) begin
    case (counter)
      4'h1:     DATA_OUT <= reg0; 
      4'h2:     DATA_OUT <= reg1;
      4'h3:     DATA_OUT <= reg2;
      4'h4:     DATA_OUT <= reg3;
      4'h5:     DATA_OUT <= reg4;
      4'h6:     DATA_OUT <= reg5;
      4'h7:     DATA_OUT <= reg6;
      4'h8:     DATA_OUT <= reg7;
      default:  DATA_OUT <= 8'hXX;
    endcase
  end
endmodule
