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

module ring_router_mux_rr (
  input clk,
  input rst,

  input  dii_flit in0,
  input  dii_flit in1,

  output dii_flit out_mux,

  output logic in0_ready,
  output logic in1_ready,

  input out_mux_ready
);

  enum { NOWORM0, NOWORM1, WORM0, WORM1 } state, nxt_state;

  always_ff @(posedge clk) begin
    if (rst) begin
      state <= NOWORM0;
    end
    else begin
      state <= nxt_state;
    end
  end

  always_comb begin
    nxt_state = state;
    out_mux.valid = 0;
    out_mux.data = 'x;
    out_mux.last = 'x;
    in0_ready = 0;
    in1_ready = 0;

    case (state)
      NOWORM0: begin
        if (in0.valid) begin
          in0_ready = out_mux_ready;
          out_mux = in0;
          out_mux.valid = 1;

          if (!in0.last) begin
            nxt_state = WORM0;
          end
        end
        else if (in1.valid) begin
          in1_ready = out_mux_ready;
          out_mux = in1;
          out_mux.valid = 1;

          if (!in1.last) begin
            nxt_state = WORM1;
          end
        end
      end
      NOWORM1: begin
        if (in1.valid) begin
          in1_ready = out_mux_ready;
          out_mux = in1;
          out_mux.valid = 1;

          if (!in1.last) begin
            nxt_state = WORM1;
          end
        end
        else if (in0.valid) begin
          in0_ready = out_mux_ready;
          out_mux = in0;
          out_mux.valid = 1;

          if (!in0.last) begin
            nxt_state = WORM0;
          end
        end
      end
      WORM0: begin
        in0_ready = out_mux_ready;
        out_mux = in0;

        if (out_mux.last & out_mux.valid & out_mux_ready) begin
          nxt_state = NOWORM1;
        end
      end
      WORM1: begin
        in1_ready = out_mux_ready;
        out_mux = in1;

        if (out_mux.last & out_mux.valid & out_mux_ready) begin
          nxt_state = NOWORM0;
        end
      end
    endcase
  end
endmodule
