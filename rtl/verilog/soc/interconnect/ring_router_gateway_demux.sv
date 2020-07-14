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
 *   Philipp Wagner <philipp.wagner@tum.de>
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module ring_router_gateway_demux #(
  parameter SUBNET_BITS  = 6,
  parameter LOCAL_SUBNET = 0
)
  (
    input clk,
    input rst,

    input [15:0] id,

    input  dii_flit in_ring,
    output dii_flit out_local,
    output dii_flit out_ext,
    output dii_flit out_ring,

    output reg in_ring_ready,

    input out_local_ready,
    input out_ext_ready,
    input out_ring_ready
  );

  reg worm;
  reg worm_local;
  reg worm_ext;

  logic is_local;
  logic is_ext;

  logic switch_local;
  logic switch_ext;

  assign out_local.data = in_ring.data;
  assign out_local.last = in_ring.last;
  assign out_ext.data   = in_ring.data;
  assign out_ext.last   = in_ring.last;
  assign out_ring.data  = in_ring.data;
  assign out_ring.last  = in_ring.last;

  assign is_local = (in_ring.data[15:0] == id);
  assign is_ext   = (in_ring.data[15:16-SUBNET_BITS] != LOCAL_SUBNET);

  always_ff @(posedge clk) begin
    if (rst) begin
      worm <= 0;
      worm_local <= 1'bx;
      worm_ext <= 1'bx;
    end
    else begin
      if (!worm) begin
        worm_local <= is_local;
        worm_ext <= is_ext;
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
  assign switch_ext   = worm ? worm_ext : is_ext;

  always_comb begin
    out_local.valid = 1'b0;
    out_ext.valid   = 1'b0;
    out_ring.valid  = 1'b0;
    in_ring_ready   = 1'b0;

    if (switch_local) begin
      out_local.valid = in_ring.valid;
      in_ring_ready   = out_local_ready;
    end
    else if (switch_ext) begin
      out_ext.valid = in_ring.valid;
      in_ring_ready = out_ext_ready;
    end
    else begin
      out_ring.valid = in_ring.valid;
      in_ring_ready  = out_ring_ready;
    end
  end
endmodule
