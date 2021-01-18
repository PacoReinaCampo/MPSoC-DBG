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
 *   Stefan Wallentowitz <stefan.wallentowitz@tum.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module osd_him #(
  parameter MAX_PKT_LEN = 12
)
  (
    input clk,
    input rst,

    glip_channel.slave  glip_in,
    glip_channel.master glip_out,

    output dii_flit dii_out,
    input           dii_out_ready,
    input  dii_flit dii_in,
    output          dii_in_ready
  );

  localparam BUF_SIZE = MAX_PKT_LEN;

  dii_flit dii_ingress;

  logic dii_ingress_ready;

  logic ingress_active;

  logic [4:0] ingress_size;

  logic [15:0] ingress_data;

  assign ingress_data = glip_in.data;

  assign glip_in.ready     = !ingress_active | dii_ingress_ready;
  assign dii_ingress.data  = ingress_data;
  assign dii_ingress.valid = ingress_active & glip_in.valid;
  assign dii_ingress.last  = ingress_active & (ingress_size == 0);

  always @(posedge clk) begin
    if (rst) begin
      ingress_active <= 0;
    end
    else begin
      if (!ingress_active) begin
        if (glip_in.valid & glip_in.ready) begin
          ingress_size <= ingress_data[4:0] - 1;
          ingress_active <= 1;
        end
      end
      else begin
        if (glip_in.valid & glip_in.ready) begin
          ingress_size <= ingress_size - 1;
          if (ingress_size == 0) begin
            ingress_active <= 0;
          end
        end
      end
    end
  end

  dii_buffer #(
    .BUF_SIZE(BUF_SIZE),
    .FULLPACKET(1)
  )
  u_ingress_buffer(
    .*,
    .packet_size    (),
    .flit_in        (dii_ingress),
    .flit_in_ready  (dii_ingress_ready),
    .flit_out       (dii_out),
    .flit_out_ready (dii_out_ready)
  );

  dii_flit dii_egress;

  logic dii_egress_ready;

  logic [$clog2(BUF_SIZE):0] egress_packet_size;

  logic egress_active;

  logic [15:0] egress_data;

  always @(*) begin
    if (!egress_active) begin
      egress_data = 0;
      egress_data[$clog2(BUF_SIZE):0] = egress_packet_size;
    end
    else begin
      egress_data = dii_egress.data;
    end
  end

  always @(*) begin
    glip_out.data = egress_data;
    glip_out.valid = dii_egress.valid;
    dii_egress_ready = egress_active & glip_out.ready;
  end

  always @(posedge clk) begin
    if (rst) begin
      egress_active <= 0;
    end
    else begin
      if (!egress_active) begin
        if (dii_egress.valid & glip_out.ready) begin
          egress_active <= 1;
        end
      end
      else begin
        if (dii_egress.valid & dii_egress_ready & dii_egress.last) begin
          egress_active <= 0;
        end
      end
    end
  end

  dii_buffer #(
    .BUF_SIZE(BUF_SIZE),
    .FULLPACKET(1)
  )
  u_egress_buffer(
    .*,
    .packet_size    (egress_packet_size),
    .flit_in        (dii_in),
    .flit_in_ready  (dii_in_ready),
    .flit_out       (dii_egress),
    .flit_out_ready (dii_egress_ready)
  );
endmodule
