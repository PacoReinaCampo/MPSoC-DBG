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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

module adbg_crc32 (
  input         clk,
  input         data,
  input         enable,
  input         shift,
  input         clr,
  input         rst,
  output [31:0] crc_out,
  output        serial_out
);

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  reg    [31:0] crc;
  wire   [31:0] new_crc;
  wire          data_sim;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  `ifdef SIM
  assign data_sim = (data === 1'bx || data === 1'b0) ? 1'b0 : 1'b1;
  `else
  assign data_sim = data;
  `endif

  // You may notice that the 'poly' in this implementation is backwards.
  // This is because the shift is also 'backwards', so that the data can
  // be shifted out in the same direction, which saves on logic + routing.
  assign new_crc[0]  = crc[1];
  assign new_crc[1]  = crc[2];
  assign new_crc[2]  = crc[3];
  assign new_crc[3]  = crc[4];
  assign new_crc[4]  = crc[5];
  assign new_crc[5]  = crc[6] ^ data_sim ^ crc[0];
  assign new_crc[6]  = crc[7];
  assign new_crc[7]  = crc[8];
  assign new_crc[8]  = crc[9] ^ data_sim ^ crc[0];
  assign new_crc[9]  = crc[10] ^ data_sim ^ crc[0];
  assign new_crc[10] = crc[11];
  assign new_crc[11] = crc[12];
  assign new_crc[12] = crc[13];
  assign new_crc[13] = crc[14];
  assign new_crc[14] = crc[15];
  assign new_crc[15] = crc[16] ^ data_sim ^ crc[0];
  assign new_crc[16] = crc[17];
  assign new_crc[17] = crc[18];
  assign new_crc[18] = crc[19];
  assign new_crc[19] = crc[20] ^ data_sim ^ crc[0];
  assign new_crc[20] = crc[21] ^ data_sim ^ crc[0];
  assign new_crc[21] = crc[22] ^ data_sim ^ crc[0];
  assign new_crc[22] = crc[23];
  assign new_crc[23] = crc[24] ^ data_sim ^ crc[0];
  assign new_crc[24] = crc[25] ^ data_sim ^ crc[0];
  assign new_crc[25] = crc[26];
  assign new_crc[26] = crc[27] ^ data_sim ^ crc[0];
  assign new_crc[27] = crc[28] ^ data_sim ^ crc[0];
  assign new_crc[28] = crc[29];
  assign new_crc[29] = crc[30] ^ data_sim ^ crc[0];
  assign new_crc[30] = crc[31] ^ data_sim ^ crc[0];
  assign new_crc[31] =           data_sim ^ crc[0];

  always @ (posedge clk or posedge rst) begin
    if(rst)
      crc[31:0] <= 32'hffffffff;
    else if(clr)
      crc[31:0] <= 32'hffffffff;
    else if(enable)
      crc[31:0] <= new_crc;
    else if (shift)
      crc[31:0] <= {1'b0, crc[31:1]};
  end

  //assign crc_match = (crc == 32'h0);
  assign crc_out = crc; //[31];
  assign serial_out = crc[0];
endmodule
