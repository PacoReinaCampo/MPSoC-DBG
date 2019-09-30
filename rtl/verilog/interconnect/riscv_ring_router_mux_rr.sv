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

module riscv_ring_router_mux_rr #(
  parameter XLEN = 64
)
  (
    input                     clk,
    input                     rst,

    input        [XLEN  -1:0] in0_data,
    input                     in0_last,
    input                     in0_valid,
    output logic              in0_ready,

    input        [XLEN  -1:0] in1_data,
    input                     in1_last,
    input                     in1_valid,
    output logic              in1_ready,

    output logic [XLEN  -1:0] out_mux_data,
    output logic              out_mux_last,
    output logic              out_mux_valid,
    input                     out_mux_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  localparam NOWORM0 = 2'b00;
  localparam NOWORM1 = 2'b01;
  localparam WORM0   = 2'b10;
  localparam WORM1   = 2'b11;

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
      state <= NOWORM0;
    end
    else begin
      state <= nxt_state;
    end
  end

  always @(*) begin
    nxt_state     <= state;
    out_mux_valid <= 0;
    out_mux_data  <= 'x;
    out_mux_last  <= 'x;
    in0_ready     <= 0;
    in1_ready     <= 0;

    case (state)
      NOWORM0: begin
        if (in0_valid) begin
          out_mux_data  <= in0_data;
          out_mux_last  <= in0_last;
          out_mux_valid <= 1;
          in0_ready     <= out_mux_ready;

          if (!in0_last) begin
            nxt_state <= WORM0;
          end
        end
        else if (in1_valid) begin
          out_mux_data  <= in1_data;
          out_mux_last  <= in1_last;
          out_mux_valid <= 1;
          in1_ready     <= out_mux_ready;

          if (!in1_last) begin
            nxt_state <= WORM1;
          end
        end
      end
      NOWORM1: begin
        if (in1_valid) begin
          out_mux_data  <= in1_data;
          out_mux_last  <= in1_last;
          out_mux_valid <= 1;
          in1_ready     <= out_mux_ready;

          if (!in1_last) begin
            nxt_state <= WORM1;
          end
        end
        else if (in0_valid) begin
          out_mux_data  <= in0_data;
          out_mux_last  <= in0_last;
          out_mux_valid <= 1;
          in0_ready     <= out_mux_ready;

          if (!in0_last) begin
            nxt_state <= WORM0;
          end
        end
      end
      WORM0: begin
        out_mux_data  <= in1_data;
        out_mux_last  <= in1_last;
        out_mux_valid <= in1_valid;
        in0_ready     <= out_mux_ready;

        if (out_mux_last & out_mux_valid & out_mux_ready) begin
          nxt_state <= NOWORM1;
        end
      end
      WORM1: begin
        out_mux_data  <= in1_data;
        out_mux_last  <= in1_last;
        out_mux_valid <= in1_valid;
        in0_ready     <= out_mux_ready;

        if (out_mux_last & out_mux_valid & out_mux_ready) begin
          nxt_state <= NOWORM0;
        end
      end
    endcase // case (state)
  end
endmodule // ring_router_mux
