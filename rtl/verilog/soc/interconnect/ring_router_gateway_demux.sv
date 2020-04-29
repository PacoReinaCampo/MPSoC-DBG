// Copyright 2016 by the authors
//
// Copyright and related rights are licensed under the Solderpad
// Hardware License, Version 0.51 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a
// copy of the License at http://solderpad.org/licenses/SHL-0.51.
// Unless required by applicable law or agreed to in writing,
// software, hardware and materials distributed under this License is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the
// License.
//
// Authors:
//    Philipp Wagner <philipp.wagner@tum.de>
//    Stefan Wallentowitz <stefan@wallentowitz.de>

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
