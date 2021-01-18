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
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Anuj Rao <anujnr@gmail.com>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

module osd_tracesample #(
  parameter WIDTH = 16
)
  (
    input              clk,
    input              rst,

    input  [WIDTH-1:0] sample_data,
    input              sample_valid,

    output [WIDTH-1:0] fifo_data,
    output             fifo_overflow,
    output             fifo_valid,
    input              fifo_ready
  );

  reg [15:0]          ov_counter;

  logic               passthrough;

  logic               ov_increment;
  logic               ov_saturate;
  logic               ov_complete;
  logic               ov_again;

  assign passthrough = (ov_counter == 0);

  assign fifo_data[15:0] = passthrough ? sample_data[15:0] : ov_counter;

  generate
    if (WIDTH > 16)
      assign fifo_data[WIDTH-1:16] = sample_data[WIDTH-1:16];
  endgenerate

  assign fifo_overflow = ~passthrough;
  assign fifo_valid    = passthrough ? sample_valid : 1'b1;

  assign ov_increment = (sample_valid & !fifo_ready);
  assign ov_saturate  = &ov_counter;
  assign ov_complete  = fifo_overflow & fifo_ready & !sample_valid;
  assign ov_again     = fifo_overflow & fifo_ready & sample_valid;

  always_ff @(posedge clk) begin
    if (rst | ov_complete)
      ov_counter <= 0;
    else if (ov_again)
      ov_counter <= 1;
    else if (ov_increment & !ov_saturate)
      ov_counter <= ov_counter + 1;
  end
endmodule
