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

module ring_router_mux (
  input clk,
  input rst,

  input  dii_flit in_ring,
  input  dii_flit in_local,
  output dii_flit out_mux,

  output logic in_ring_ready,
  output logic in_local_ready,

  input out_mux_ready
);

  enum { NOWORM, WORM_LOCAL, WORM_RING } state, nxt_state;

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= NOWORM;
    end
    else begin
      state <= nxt_state;
    end
  end

  always_comb begin
    nxt_state = state;
    out_mux.valid  = 0;
    out_mux.data   = 'x;
    out_mux.last   = 'x;
    in_ring_ready  = 0;
    in_local_ready = 0;

    case (state)
      NOWORM: begin
        if (in_ring.valid) begin
          in_ring_ready = out_mux_ready;
          out_mux       = in_ring;
          out_mux.valid = 1'b1;

          if (!in_ring.last) begin
            nxt_state = WORM_RING;
          end
        end
        else if (in_local.valid) begin
          in_local_ready = out_mux_ready;
          out_mux        = in_local;
          out_mux.valid  = 1'b1;

          if (!in_local.last) begin
            nxt_state = WORM_LOCAL;
          end
        end
      end
      WORM_RING: begin
        in_ring_ready = out_mux_ready;
        out_mux.valid = in_ring.valid;
        out_mux.last  = in_ring.last;
        out_mux.data  = in_ring.data;

        if (out_mux.last & out_mux.valid & out_mux_ready) begin
          nxt_state = NOWORM;
        end
      end
      WORM_LOCAL: begin
        in_local_ready = out_mux_ready;
        out_mux.valid  = in_local.valid;
        out_mux.last   = in_local.last;
        out_mux.data   = in_local.data;

        if (out_mux.last & out_mux.valid & out_mux_ready) begin
          nxt_state = NOWORM;
        end
      end
    endcase
  end
endmodule
