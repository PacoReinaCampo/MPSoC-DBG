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

module riscv_ring_router_mux #(
  parameter XLEN = 64
)
  (
    input                     clk,
    input                     rst,

    input        [XLEN  -1:0] in_ring_data,
    input                     in_ring_last,
    input                     in_ring_valid,
    output logic              in_ring_ready,

    input        [XLEN  -1:0] in_local_data,
    input                     in_local_last,
    input                     in_local_valid,
    output logic              in_local_ready,

    output logic [XLEN  -1:0] out_mux_data,
    output logic              out_mux_last,
    output logic              out_mux_valid,
    input                     out_mux_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  localparam NOWORM     = 2'b00;
  localparam WORM_LOCAL = 2'b01;
  localparam WORM_RING  = 2'b10;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [1:0] state;
  logic [1:0] nxt_state;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  always @(posedge clk) begin
    if (rst) begin
      state <= NOWORM;
    end
    else begin
      state <= nxt_state;
    end
  end

  always @(*) begin
    nxt_state <= state;
    out_mux_valid <= 0;
    out_mux_data <= 'x;
    out_mux_last <= 'x;
    in_ring_ready <= 0;
    in_local_ready <= 0;

    case (state)
      NOWORM: begin
        if (in_ring_valid) begin
          out_mux_data <= in_ring_data;
          out_mux_last <= in_ring_last;
          out_mux_valid <= 1'b1;
          in_ring_ready <= out_mux_ready;

          if (!in_ring_last) begin
            nxt_state <= WORM_RING;
          end
        end
        else if (in_local_valid) begin
          out_mux_data   <= in_local_data;
          out_mux_last   <= in_local_last;
          out_mux_valid  <= 1'b1;
          in_local_ready <= out_mux_ready;

          if (!in_local_last) begin
            nxt_state <= WORM_LOCAL;
          end
        end // if (in_local_valid)
      end // case: NOWORM
      WORM_RING: begin
        in_ring_ready <= out_mux_ready;
        out_mux_valid <= in_ring_valid;
        out_mux_last <= in_ring_last;
        out_mux_data <= in_ring_data;

        if (out_mux_last & out_mux_valid & out_mux_ready) begin
          nxt_state <= NOWORM;
        end
      end
      WORM_LOCAL: begin
        in_local_ready <= out_mux_ready;
        out_mux_valid <= in_local_valid;
        out_mux_last <= in_local_last;
        out_mux_data <= in_local_data;

        if (out_mux_last & out_mux_valid & out_mux_ready) begin
          nxt_state <= NOWORM;
        end
      end
    endcase // case (state)
  end
endmodule // ring_router_mux
