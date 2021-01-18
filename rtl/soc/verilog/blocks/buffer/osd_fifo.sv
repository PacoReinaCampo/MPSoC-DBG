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

module osd_fifo #(
  parameter WIDTH = 'x,
  parameter DEPTH = 'x
)
  (
    input              clk,
    input              rst,

    input [WIDTH-1:0]  in_data,
    input              in_valid,
    output             in_ready,

    output [WIDTH-1:0] out_data,
    output             out_valid,
    input              out_ready
  );

  // Signals for fifo
  reg [WIDTH-1:0] fifo_data     [0:DEPTH-1]; //actual fifo
  reg [WIDTH-1:0] nxt_fifo_data [0:DEPTH-1];

  reg [DEPTH:0]   fifo_write_ptr;

  wire            pop;
  wire            push;

  assign pop = out_valid & out_ready;
  assign push = in_valid & in_ready;

  assign out_data = fifo_data[0];
  assign out_valid = !fifo_write_ptr[0];

  assign in_ready = !fifo_write_ptr[DEPTH];

  always @(posedge clk) begin
    if (rst) begin
      fifo_write_ptr <= {{DEPTH{1'b0}},1'b1};
    end
    else if (push & !pop) begin
      fifo_write_ptr <= fifo_write_ptr << 1;
    end
    else if (!push & pop) begin
      fifo_write_ptr <= fifo_write_ptr >> 1;
    end
  end

  always @(*) begin : shift_register_comb
    integer i;
    for (i=0;i<DEPTH;i=i+1) begin
      if (pop) begin
        if (push & fifo_write_ptr[i+1]) begin
          nxt_fifo_data[i] = in_data;
        end
        else if (i<DEPTH-1) begin
          nxt_fifo_data[i] = fifo_data[i+1];
        end
        else begin
          nxt_fifo_data[i] = fifo_data[i];
        end
      end
      else if (push & fifo_write_ptr[i]) begin
        nxt_fifo_data[i] = in_data;
      end
      else begin
        nxt_fifo_data[i] = fifo_data[i];
      end
    end
  end

  always @(posedge clk) begin : shift_register_seq
    integer i;
    for (i=0;i<DEPTH;i=i+1) begin
      fifo_data[i] <= nxt_fifo_data[i];
    end
  end
endmodule
