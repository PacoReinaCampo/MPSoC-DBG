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

module riscv_osd_event_packetization_fixedwidth #(
  parameter XLEN       = 64,
  parameter DATA_WIDTH = 64
)
  (
    input                  clk,
    input                  rst,

    output [XLEN     -1:0] debug_out_data,
    output                 debug_out_last,
    output                 debug_out_valid,
    input                  debug_out_ready,

    // DI address of this module (SRC)
    input [XLEN-1      :0] id,

    // DI address of the event destination (DEST)
    input [XLEN-1      :0] dest,
    // Generate an overflow packet
    input                  overflow,

    // a new event is available
    input                  event_available,
    // the packet has been sent
    output                 event_consumed,

    input [DATA_WIDTH-1:0] data
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [$clog2(`MAX_DATA_NUM_WORDS)-1:0] data_req_idx;
  logic [XLEN-1:0] data_word;

  // number of bits to fill in the last word
  logic [3:0] fill_last;

  integer i;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //
  assign fill_last = (XLEN - DATA_WIDTH % XLEN);

  always @(*) begin
    if (data_req_idx < `MAX_DATA_NUM_WORDS - 1) begin
      data_word = data[(data_req_idx+1)*XLEN-1 -: XLEN];
    end
    else if (data_req_idx == `MAX_DATA_NUM_WORDS - 1) begin
      // last word must be padded with 0s if the data doesn't fill a word
      for (i = 0; i < XLEN; i=i+1) begin
        if (i < fill_last) begin
          data_word[XLEN-i-1] = 1'b0;
        end
        else begin
          data_word[XLEN-i-1] = data[DATA_WIDTH - 1 - (i - fill_last)];
        end
      end
    end
    else begin
      data_word = 64'h0;
    end
  end

  riscv_osd_event_packetization #(
    .XLEN       (XLEN),
    .DATA_WIDTH (DATA_WIDTH),

    .MAX_DATA_NUM_WORDS (`MAX_DATA_NUM_WORDS)
  )
  osd_event_packetization (
    .clk (clk),
    .rst (rst),

    .debug_out_data   (debug_out_data),
    .debug_out_last   (debug_out_last),
    .debug_out_valid  (debug_out_valid),
    .debug_out_ready  (debug_out_ready),

    .id              (id),
    .dest            (dest),
    .overflow        (overflow),
    .event_available (event_available),
    .event_consumed  (event_consumed),

    .data_num_words (),
    .data_req_valid (),
    .data_req_idx   (data_req_idx),

    .data (data_word)
  );
endmodule
