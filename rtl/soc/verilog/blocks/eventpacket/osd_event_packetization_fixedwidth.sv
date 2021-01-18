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
 *   Philipp Wagner <philipp.wagner@tum.de>
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

/*
 * Module: osd_event_packetization_fixedwidth
 *
 * Package data into one or multiple DI event packet (TYPE == EVENT). If the
 * maximum number of flits (MAX_PKT_LEN) is exceeded two or more packets are
 * generated. The first packet has TYPE_SUB set to 0, the continued packets
 * have TYPE_SUB set to 1.
 *
 * If event_overflow is set an overflow packet is generated. An overflow packet
 * has TYPE_SUB set to 5 and contains the number of overflowed packets in the
 * first payload flit. The number of overflowed packets is passed in
 * event_data[15:0].
 */

import dii_package::dii_flit;

module osd_event_packetization_fixedwidth #(
  //The maximum length of a DI packet in flits, including the header flits
  parameter MAX_PKT_LEN = 12,

  // Width of |data| in bit
  parameter DATA_WIDTH = 'x,

  localparam DATA_NUM_WORDS = ((DATA_WIDTH + 15) >> 4)
)
  (
    input                  clk,
    input                  rst,

    output dii_flit        debug_out,
    input                  debug_out_ready,

    // DI address of this module (SRC)
    input [15:0]           id,

    // DI address of the event destination (DEST)
    input [15:0]           dest,

    // Generate an overflow packet
    input                  overflow,

    // a new event is available
    input                  event_available,

    // the packet has been sent
    output                 event_consumed,

    input [DATA_WIDTH-1:0] data
  );

  logic [$clog2(DATA_NUM_WORDS)-1:0] data_req_idx;
  logic [15:0] data_word;

  // number of bits to fill in the last word
  logic [3:0] fill_last;

  assign fill_last = 4'(16 - DATA_WIDTH % 16);

  always_comb begin
    if (data_req_idx < DATA_NUM_WORDS - 1) begin
      data_word = data[(data_req_idx+1)*16-1 -: 16];
    end
    else if (data_req_idx == DATA_NUM_WORDS - 1) begin
      // last word must be padded with 0s if the data doesn't fill a word
      integer i;
      for (i = 0; i < 16; i = i + 1) begin
        if (i < fill_last) begin
          data_word[15-i] = 1'b0;
        end
        else begin
          data_word[15-i] = data[DATA_WIDTH - 1 - (i - fill_last)];
        end
      end
    end
    else begin
      data_word = 16'h0;
    end
  end

  osd_event_packetization #(
    .MAX_PKT_LEN        (MAX_PKT_LEN),
    .MAX_DATA_NUM_WORDS (DATA_NUM_WORDS)
  )
  u_packetization(
    .clk(clk),
    .rst(rst),

    .debug_out       (debug_out),
    .debug_out_ready (debug_out_ready),

    .id (id),

    .dest            (dest),
    .overflow        (overflow),
    .event_available (event_available),
    .event_consumed  (event_consumed),

    .data_num_words ($clog2(DATA_NUM_WORDS+1)'(DATA_NUM_WORDS)),
    .data_req_valid (),
    .data_req_idx   (data_req_idx),

    .data (data_word)
  );
endmodule
