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

module debug_ring_expand #(
  parameter PORTS = 1,
  parameter BUFFER_SIZE = 4
)
  (
    input clk,
    input rst,
    input [PORTS-1:0][15:0] id_map,

    input  dii_flit [PORTS-1:0] dii_in,
    output dii_flit [PORTS-1:0] dii_out,

    output [PORTS-1:0] dii_in_ready,
    input  [PORTS-1:0] dii_out_ready,

    input  dii_flit [1:0] ext_in,
    output dii_flit [1:0] ext_out,

    output [1:0] ext_in_ready, // extension input ports
    input  [1:0] ext_out_ready // extension output ports
  );

  genvar i;

  dii_flit [1:0][PORTS:0] chain;

  logic [1:0][PORTS:0] chain_ready;

  generate
    for(i=0; i<PORTS; i++) begin : gen_router
      ring_router #(
        .BUFFER_SIZE(BUFFER_SIZE)
      )
      u_router (
        .*,
        .id              ( id_map         [i]          ),
        .ring_in0        ( chain       [0][i]          ),
        .ring_in0_ready  ( chain_ready [0][i]          ),
        .ring_in1        ( chain       [1][i]          ),
        .ring_in1_ready  ( chain_ready [1][i]          ),
        .ring_out0       ( chain       [0][i+1]        ),
        .ring_out0_ready ( chain_ready [0][i+1]        ),
        .ring_out1       ( chain       [1][i+1]        ),
        .ring_out1_ready ( chain_ready [1][i+1]        ),
        .local_in        ( dii_in         [i]          ),
        .local_in_ready  ( dii_in_ready   [i]          ),
        .local_out       ( dii_out        [i]          ),
        .local_out_ready ( dii_out_ready  [i]          )
      );
    end
  endgenerate

  // the expanded ports
  generate
    for(i=0; i<2; i++) begin
      assign chain[i][0] = ext_in[i];
      assign ext_in_ready[i] = chain_ready[i][0];
      assign ext_out[i] = chain[i][PORTS];
      assign chain_ready[i][PORTS] = ext_out_ready[i];
    end
  endgenerate
endmodule
