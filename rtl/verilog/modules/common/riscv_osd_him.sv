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

`include "riscv_dbg_pkg.sv"

module riscv_osd_him #(
  parameter XLEN = 64,

  parameter BUFFER_SIZE = 4
)
  (
    input               clk,
    input               rst,

    //GLIP host connection
    input  [XLEN  -1:0] glip_in_data,
    input               glip_in_valid,
    output              glip_in_ready,

    output [XLEN  -1:0] glip_out_data,
    output              glip_out_valid,
    input               glip_out_ready,

    output [XLEN  -1:0] dii_out_data,
    output              dii_out_last,
    output              dii_out_valid,
    input               dii_out_ready,

    input  [XLEN  -1:0] dii_in_data,
    input               dii_in_last,
    input               dii_in_valid,
    output              dii_in_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [XLEN  -1:0] dii_ingress_data;
  logic              dii_ingress_last;
  logic              dii_ingress_valid;
  logic              dii_ingress_ready;

  logic              ingress_active;
  logic [       4:0] ingress_size;
  logic [XLEN  -1:0] ingress_data;

  logic [XLEN  -1:0] dii_egress_data;
  logic              dii_egress_last;
  logic              dii_egress_valid;
  logic              dii_egress_ready;

  logic [$clog2(BUFFER_SIZE):0] egress_packet_size;

  logic        egress_active;

  logic [15:0] egress_data;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign ingress_data = glip_in_data;

  assign glip_in_ready = !ingress_active | dii_ingress_ready;

  assign dii_ingress_data  = ingress_data;
  assign dii_ingress_last  = ingress_active & (ingress_size == 0);
  assign dii_ingress_valid = ingress_active & glip_in_valid;

  always @(posedge clk) begin
    if (rst) begin
      ingress_active <= 0;
    end
    else begin
      if (!ingress_active) begin
        if (glip_in_valid & glip_in_ready) begin
          ingress_size <= ingress_data[4:0] - 1;
          ingress_active <= 1;
        end
      end
      else begin
        if (glip_in_valid & glip_in_ready) begin
          ingress_size <= ingress_size - 1;
          if (ingress_size == 0) begin
            ingress_active <= 0;
          end
        end
      end
    end
  end

  riscv_dii_buffer #(
    .XLEN        (XLEN),
    .BUFFER_SIZE (BUFFER_SIZE),
    .FULLPACKET  (0)
  )
  ingress_buffer (
    .clk (clk),
    .rst (rst),

    .packet_size (),

    .flit_in_data  (dii_ingress_data),
    .flit_in_last  (dii_ingress_last),
    .flit_in_valid (dii_ingress_valid),
    .flit_in_ready (dii_ingress_ready),

    .flit_out_data  (dii_out_data),
    .flit_out_last  (dii_out_last),
    .flit_out_valid (dii_out_valid),
    .flit_out_ready (dii_out_ready)
  );

  always @(*) begin
    if (!egress_active) begin
      egress_data = 0;
      egress_data[$clog2(BUFFER_SIZE):0] = egress_packet_size;
    end
    else begin
      egress_data = dii_egress_data;
    end
  end

  assign glip_out_data = egress_data;
  assign glip_out_valid = dii_egress_valid;
  assign dii_egress_ready = egress_active & glip_out_ready;

  always @(posedge clk) begin
    if (rst) begin
      egress_active <= 0;
    end
    else begin
      if (!egress_active) begin
        if (dii_egress_valid & glip_out_ready) begin
          egress_active <= 1;
        end
      end
      else begin
        if (dii_egress_valid & dii_egress_ready & dii_egress_last) begin
          egress_active <= 0;
        end
      end
    end
  end

  riscv_dii_buffer #(
    .XLEN        (XLEN),
    .BUFFER_SIZE (BUFFER_SIZE),
    .FULLPACKET  (0)
  )
  egress_buffer (
    .clk (clk),
    .rst (rst),

    .packet_size (egress_packet_size),

    .flit_in_data  (dii_in_data),
    .flit_in_last  (dii_in_last),
    .flit_in_valid (dii_in_valid),
    .flit_in_ready (dii_in_ready),

    .flit_out_data  (dii_egress_data),
    .flit_out_last  (dii_egress_last),
    .flit_out_valid (dii_egress_valid),
    .flit_out_ready (dii_egress_ready)
  );
endmodule // osd_him
