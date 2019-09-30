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

module riscv_dii_buffer #(
  parameter XLEN        = 64,
  parameter BUFFER_SIZE = 4,
  parameter FULLPACKET  = 0
)
  (
    input                                clk,
    input                                rst,
    output logic [$clog2(BUFFER_SIZE):0] packet_size,

    input        [XLEN             -1:0] flit_in_data,
    input                                flit_in_last,
    input                                flit_in_valid,
    output                               flit_in_ready,

    output logic [XLEN             -1:0] flit_out_data,
    output logic                         flit_out_last,
    output logic                         flit_out_valid,
    input                                flit_out_ready
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  // the width of the index
  localparam ID_W = $clog2(BUFFER_SIZE);

  //////////////////////////////////////////////////////////////////
  //
  // Functions
  //
  function [ID_W:0] find_first_one;
    input [BUFFER_SIZE:0] data;
    integer i;
    for (i = BUFFER_SIZE; i > 0; i=i-1)
      if (data[i]) find_first_one = i;
  endfunction // size_count

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // internal shift register
  logic [BUFFER_SIZE-1:0][`WIDTH-1:0] data_data;
  logic [BUFFER_SIZE-1:0]             data_last;
  logic [BUFFER_SIZE-1:0]             data_valid;

  reg   [ID_W:0] rp; // read pointer
  logic          reg_out_valid;  // local output valid
  logic          flit_in_fire;
  logic          flit_out_fire;

  logic [BUFFER_SIZE-1:0] data_last_buf;
  logic [BUFFER_SIZE-1:0] data_last_shifted;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign flit_in_ready = (rp != BUFFER_SIZE - 1) || !reg_out_valid;
  assign flit_in_fire = flit_in_valid && flit_in_ready;
  assign flit_out_fire = flit_out_valid && flit_out_ready;

  always @(posedge clk) begin
    if(rst)
      reg_out_valid <= 0;
    else if(flit_in_valid)
      reg_out_valid <= 1;
    else if(flit_out_fire && rp == 0)
      reg_out_valid <= 0;
  end

  always @(posedge clk) begin
    if(rst)
      rp <= 0;
    else if(flit_in_fire && !flit_out_fire && reg_out_valid)
      rp <= rp + 1;
    else if(flit_out_fire && !flit_in_fire && rp != 0)
      rp <= rp - 1;
  end

  always @(posedge clk) begin
    if(flit_in_fire) begin
      data_data  <= {data_data,  flit_in_data};
      data_last  <= {data_last,  flit_in_last};
      data_valid <= {data_valid, flit_in_valid};
    end
  end

  generate
     // SRL does not allow parallel read
    if(FULLPACKET != 0) begin
      always @(posedge clk)
        if(rst)
          data_last_buf <= 0;
        else if(flit_in_fire)
        data_last_buf <= {data_last_buf, flit_in_last && flit_in_valid};

      // extra logic to get the packet size in a stable manner
      assign data_last_shifted = data_last_buf << BUFFER_SIZE - 1 - rp;

      assign packet_size = BUFFER_SIZE - find_first_one(data_last_shifted);

      always @* begin
        flit_out_data  <= data_data[rp];
        flit_out_last  <= data_last[rp];
        flit_out_valid <= reg_out_valid && |data_last_shifted;
      end
    end
    else begin // if (FULLPACKET)
      assign packet_size = 0;
      always @* begin
        flit_out_data  <= data_data[rp];
        flit_out_last  <= data_last[rp];
        flit_out_valid <= reg_out_valid;
      end
    end
  endgenerate
endmodule // dii_buffer
