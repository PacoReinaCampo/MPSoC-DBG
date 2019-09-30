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
 *   Francisco Javier Reina Campo <frareicam@gmail.com>
 */

module riscv_ring_router_demux #(
  parameter XLEN = 64
)
  (
    input               clk,
    input               rst,

    input  [XLEN  -1:0] id,

    input  [XLEN  -1:0] in_ring_data,
    input               in_ring_last,
    input               in_ring_valid,
    output              in_ring_ready,

    output [XLEN  -1:0] out_local_data,
    output              out_local_last,
    output              out_local_valid,
    input               out_local_ready,

    output [XLEN  -1:0] out_ring_data,
    output              out_ring_last,
    output              out_ring_valid,
    input               out_ring_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  reg         worm;
  reg         worm_local;

  logic       is_local;

  logic switch_local;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign out_local_data = in_ring_data;
  assign out_local_last = in_ring_last;
  assign out_ring_data  = in_ring_data;
  assign out_ring_last  = in_ring_last;

  assign is_local = (in_ring_data == id);

  always @(posedge clk) begin
    if (rst) begin
      worm       <= 1'b0;
      worm_local <= 1'bx;
    end
    else begin
      if (!worm) begin
        worm_local <= is_local;
        if (in_ring_ready & in_ring_valid & !in_ring_last) begin
          worm <= 1'b1;
        end
      end
      else begin
        if (in_ring_ready & in_ring_valid & in_ring_last) begin
          worm <= 1'b0;
        end
      end
    end
  end

  assign switch_local = worm ? worm_local : is_local;

  assign out_ring_valid  = !switch_local & in_ring_valid;
  assign out_local_valid = switch_local & in_ring_valid;

  assign in_ring_ready = switch_local ? out_local_ready : out_ring_ready;
endmodule // ring_router_demux
