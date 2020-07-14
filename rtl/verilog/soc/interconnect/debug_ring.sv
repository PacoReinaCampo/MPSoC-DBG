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

module debug_ring #(
  parameter PORTS        = 1,
  parameter BUFFER_SIZE  = 4,
  parameter SUBNET_BITS  = 6,
  parameter LOCAL_SUBNET = 0
)
  (
    input clk, 
    input rst,

    input [PORTS-1:0][15:0] id_map,

    input  dii_flit [PORTS-1:0] dii_in,
    output dii_flit [PORTS-1:0] dii_out,

    output [PORTS-1:0] dii_in_ready,
    input  [PORTS-1:0] dii_out_ready
  );

  dii_flit [1:0][1:0] ext_port;

  logic [1:0][1:0] ext_port_ready;

  debug_ring_expand #(
    .PORTS       (PORTS),
    .BUFFER_SIZE (BUFFER_SIZE)
  )
  ring (
    .*,
    .ext_in        ( ext_port[0]       ),
    .ext_in_ready  ( ext_port_ready[0] ),
    .ext_out       ( ext_port[1]       ),
    .ext_out_ready ( ext_port_ready[1] )
  );

  // empty input for chain 0
  assign ext_port[0][0].valid = 1'b0;

  // connect the ends of chain 0 & 1
  assign ext_port[0][1] = ext_port[1][0];
  assign ext_port_ready[1][0] = ext_port_ready[0][1];

  // dump chain 1
  assign ext_port_ready[1][1] = 1'b1;
endmodule
