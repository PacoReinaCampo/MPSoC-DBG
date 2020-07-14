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
//              Debug on Chip Interface                                       //
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
 *   Wei Song <ws327@cam.ac.uk>
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;
import dii_package::dii_flit_assemble;

module dii_buffer #(
  parameter BUF_SIZE   = 4,  // length of the buffer
  parameter FULLPACKET = 0
)
  (
    input                               clk,
    input                               rst,

    output logic   [$clog2(BUF_SIZE):0] packet_size,

    input  dii_flit                     flit_in,
    output dii_flit                     flit_out,

    output                              flit_in_ready,
    input                               flit_out_ready
  );

  // the width of the index
  localparam ID_W = $clog2(BUF_SIZE);

  // internal shift register
  dii_flit [BUF_SIZE-1:0]   data;

  // read pointer
  reg [ID_W:0]              rp;

  // local output valid
  logic                     reg_out_valid;

  logic                     flit_in_fire;
  logic                     lit_out_fire;

  assign flit_in_ready = (rp != BUF_SIZE - 1) || !reg_out_valid;
  assign flit_in_fire = flit_in.valid && flit_in_ready;
  assign flit_out_fire = flit_out.valid && flit_out_ready;

  always_ff @(posedge clk) begin
    if(rst)
      reg_out_valid <= 0;
    else if(flit_in.valid)
      reg_out_valid <= 1;
    else if(flit_out_fire && rp == 0)
      reg_out_valid <= 0;
  end

  always_ff @(posedge clk) begin
    if(rst)
      rp <= 0;
    else if(flit_in_fire && !flit_out_fire && reg_out_valid)
      rp <= rp + 1;
    else if(flit_out_fire && !flit_in_fire && rp != 0)
      rp <= rp - 1;
  end

  always @(posedge clk) begin
    if(flit_in_fire)
      data <= {data, flit_in};
  end

  generate                     // SRL does not allow parallel read
    if(FULLPACKET != 0) begin
      logic [BUF_SIZE-1:0] data_last_buf, data_last_shifted;

      always_ff @(posedge clk) begin
        if(rst)
          data_last_buf <= 0;
        else if(flit_in_fire)
          data_last_buf <= {data_last_buf, flit_in.last && flit_in.valid};
      end

      // extra logic to get the packet size in a stable manner
      assign data_last_shifted = data_last_buf << BUF_SIZE - 1 - rp;

      function logic [ID_W:0] find_first_one(input logic [BUF_SIZE-1:0] data);
        automatic int i;
        for(i=BUF_SIZE-1; i>=0; i--)
          if(data[i]) return i;
        return BUF_SIZE;
      endfunction

      assign packet_size = BUF_SIZE - find_first_one(data_last_shifted);

      always @(*) begin
        flit_out = data[rp];
        flit_out.valid = reg_out_valid && |data_last_shifted;
      end
    end
    else begin
      assign packet_size = 0;
      always @(*) begin
        flit_out = data[rp];
        flit_out.valid = reg_out_valid;
      end
    end
  endgenerate
endmodule
