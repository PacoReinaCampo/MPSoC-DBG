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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module ring_router_demux (
  input       clk,
  input       rst,

  input [15:0] id,

  input  dii_flit in_ring,
  output dii_flit out_local,
  output dii_flit out_ring,

  output in_ring_ready,
  input  out_local_ready,
  input  out_ring_ready
);

  assign out_local.data = in_ring.data;
  assign out_local.last = in_ring.last;
  assign out_ring.data = in_ring.data;
  assign out_ring.last = in_ring.last;

  reg         worm;
  reg         worm_local;

  logic       is_local;

  logic switch_local;

  assign is_local = (in_ring.data[15:0] == id);

  always_ff @(posedge clk) begin
    if (rst) begin
      worm <= 0;
      worm_local <= 1'bx;
    end
    else begin
      if (!worm) begin
        worm_local <= is_local;
        if (in_ring_ready & in_ring.valid & !in_ring.last) begin
          worm <= 1;
        end
      end
      else begin
        if (in_ring_ready & in_ring.valid & in_ring.last) begin
          worm <= 0;
        end
      end
    end
  end
  assign switch_local = worm ? worm_local : is_local;

  assign out_ring.valid = !switch_local & in_ring.valid;
  assign out_local.valid = switch_local & in_ring.valid;

  assign in_ring_ready = switch_local ? out_local_ready : out_ring_ready;
endmodule
