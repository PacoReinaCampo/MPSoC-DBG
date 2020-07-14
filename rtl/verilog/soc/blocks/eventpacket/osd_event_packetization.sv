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

import dii_package::dii_flit;

module osd_event_packetization #(
  // The maximum length of a DI packet in flits, including the header flits
  parameter MAX_PKT_LEN = 12,

  // The maximum number of payload words the packet could consist of.
  // The actual number of payload words is given by data_num_words.
  parameter MAX_DATA_NUM_WORDS = 'hx
)
  (
    input                                     clk,
    input                                     rst,

    output dii_flit                           debug_out,
    input                                     debug_out_ready,

    // DI address of this module (SRC)
    input [15:0]                              id,

    // DI address of the event destination (DEST)
    input [15:0]                              dest,

    // Generate an overflow packet
    input                                     overflow,

    // a new event is available
    input                                     event_available,

    // the packet has been sent
    output logic                              event_consumed,

    // number of data words this event consists of
    input  [$clog2(MAX_DATA_NUM_WORDS+1)-1:0] data_num_words,

    // data request: index of the data word
    output [$clog2(MAX_DATA_NUM_WORDS)  -1:0] data_req_idx,

    // data request: request is valid
    output                                    data_req_valid,

    // a data word
    input [15:0]                              data
  );
  localparam NUM_HEADER_FLITS = 3; // header flits: SRC, DEST, FLAGS
  localparam MAX_PAYLOAD_LEN = MAX_PKT_LEN - NUM_HEADER_FLITS;

  // packet counter within a single event transfer
  localparam PKG_CNT_WIDTH = $clog2((MAX_DATA_NUM_WORDS + (MAX_PAYLOAD_LEN - 1)) / MAX_PAYLOAD_LEN);
  localparam PKG_CNT_WIDTH_NONZERO = PKG_CNT_WIDTH == 0 ? 1 : PKG_CNT_WIDTH;

  // number of packets required to transfer the event data
  // cnt from 0..(num_pkgs-1) => num_pkgs requires one more bit
  localparam NUM_PKGS_WIDTH = PKG_CNT_WIDTH + 1;

  localparam TYPE_SUB_LAST     = 4'h0;
  localparam TYPE_SUB_CONTINUE = 4'h1;
  localparam TYPE_SUB_OVERFLOW = 4'h5;

  logic [PKG_CNT_WIDTH_NONZERO-1:0] pkg_cnt, nxt_pkg_cnt;

  logic [NUM_PKGS_WIDTH-1:0] num_pkgs;

  // data word of event data
  logic [$clog2(MAX_DATA_NUM_WORDS)-1:0] word_cnt, nxt_word_cnt;

  // payload flit within the currently sent packet
  logic [$clog2(MAX_PAYLOAD_LEN)-1:0] payload_flit_cnt, nxt_payload_flit_cnt;

  assign num_pkgs = NUM_PKGS_WIDTH'((data_num_words + (MAX_PAYLOAD_LEN - 1)) / MAX_PAYLOAD_LEN);

  // FSM states
  enum {
    IDLE_DEST,
    DESTINATION,
    SOURCE, FLAGS,
    OVERFLOW,
    PAYLOAD
  } state, nxt_state;

  assign data_req_idx   = word_cnt;
  assign data_req_valid = (state == PAYLOAD || state == OVERFLOW);

  always_ff @(posedge clk) begin
    if (rst) begin
      word_cnt <= 0;
      payload_flit_cnt <= 0;
      pkg_cnt <= 0;
      state <= IDLE_DEST;
    end
    else begin
      word_cnt <= nxt_word_cnt;
      payload_flit_cnt <= nxt_payload_flit_cnt;
      pkg_cnt <= nxt_pkg_cnt;
      state <= nxt_state;
    end
  end

  always_comb begin
    event_consumed = 0;
    debug_out.valid = 0;
    debug_out.data = 'x;
    debug_out.last = 0;
    nxt_state = state;
    nxt_word_cnt = word_cnt;
    nxt_payload_flit_cnt = payload_flit_cnt;
    nxt_pkg_cnt = pkg_cnt;

    case (state)
      IDLE_DEST: begin
        debug_out.data = 16'h0;
        if (event_available) begin
          debug_out.valid = 1;
          debug_out.data = dest;
          nxt_payload_flit_cnt = 0;
          if (debug_out_ready) begin
            nxt_state = SOURCE;
          end
        end
      end
      SOURCE: begin
        debug_out.valid = 1;
        debug_out.data = id;

        if (debug_out_ready) begin
          nxt_state = FLAGS;
        end
      end
      FLAGS: begin
        debug_out.data[15:14] = 2'b10; // TYPE == EVENT

        // TYPE_SUB
        if (overflow) begin
          debug_out.data[13:10] = TYPE_SUB_OVERFLOW;
        end
        else begin
          if (pkg_cnt == num_pkgs - 1) begin
            debug_out.data[13:10] = TYPE_SUB_LAST;
          end
          else begin
            debug_out.data[13:10] = TYPE_SUB_CONTINUE;
          end
        end

        debug_out.data[9:0] = 10'h0; // reserved
        debug_out.valid = 1;

        if (debug_out_ready)
          nxt_state = overflow ? OVERFLOW : PAYLOAD;
      end
      OVERFLOW: begin
        debug_out.valid = 1;
        debug_out.data = data;
        debug_out.last = 1;
        if (debug_out_ready) begin
          nxt_state = IDLE_DEST;
          event_consumed = 1'b1;
        end
      end
      PAYLOAD: begin
        debug_out.valid = 1;

        if (word_cnt < data_num_words - 1) begin
          debug_out.data = data;
          debug_out.last = (payload_flit_cnt == MAX_PAYLOAD_LEN - 1);

          if (debug_out_ready) begin
            nxt_word_cnt = word_cnt + 1;

            if (payload_flit_cnt == MAX_PAYLOAD_LEN - 1) begin
              // we need to continue the transfer in the next packet
              nxt_state = IDLE_DEST;
              nxt_pkg_cnt = pkg_cnt + 1;
              nxt_payload_flit_cnt = 0;
            end
            else begin
              nxt_state = PAYLOAD;
              nxt_payload_flit_cnt = payload_flit_cnt + 1;
            end

          end
        end
        else begin
          // last payload word of the transfer
          debug_out.last = 1;
          debug_out.data = data;

          if (debug_out_ready) begin
            event_consumed = 1'b1;
            nxt_state = IDLE_DEST;
            nxt_pkg_cnt = 0;
            nxt_word_cnt = 0;
          end
        end
      end
    endcase
  end
endmodule
