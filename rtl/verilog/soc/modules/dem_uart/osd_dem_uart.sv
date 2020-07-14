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
 *   Stefan Wallentowitz <stefan@wallentowitz.de>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module osd_dem_uart (
  input clk,
  input rst,

  input            dii_flit debug_in,
  output           dii_flit debug_out,

  output           debug_in_ready,
  input            debug_out_ready,

  input     [15:0] id,

  output           drop,

  input      [7:0] out_char,
  input            out_valid,
  output reg       out_ready,

  output reg [7:0] in_char,
  output reg       in_valid,
  input            in_ready
);

  localparam TYPE_EVENT          = 2'b10;
  localparam TYPE_SUB_EVENT_LAST = 4'b0000;

  logic         stall;

  dii_flit     c_uart_out, c_uart_in;
  logic        c_uart_out_ready, c_uart_in_ready;

  reg [15:0]   event_dest;
  reg [ 7:0]   out_char_buf;

  enum { STATE_IDLE, STATE_HDR_DEST, STATE_HDR_SRC, STATE_HDR_FLAGS, STATE_XFER } state_tx, state_rx;

  assign drop = stall;

  osd_regaccess_layer #(
    .MOD_VENDOR(16'h1),
    .MOD_TYPE(16'h2),
    .MOD_VERSION(16'h0),
    .MAX_REG_SIZE(16),
    .CAN_STALL(1),
    .MOD_EVENT_DEST_DEFAULT(16'h0)
  )
  u_regaccess(
    .clk (clk),
    .rst (rst),

    .id (id),

    .debug_in (debug_in),
    .debug_in_ready (debug_in_ready),
    .debug_out (debug_out),
    .debug_out_ready (debug_out_ready),
    .module_in (c_uart_out),
    .module_in_ready (c_uart_out_ready),
    .module_out (c_uart_in),
    .module_out_ready (c_uart_in_ready),
    .stall (stall),
    .event_dest(event_dest),
    .reg_request (),
    .reg_write (),
    .reg_addr (),
    .reg_size (),
    .reg_wdata (),
    .reg_ack (1'b0),
    .reg_err (1'b0),
    .reg_rdata (16'h0)
  );

  always @(posedge clk) begin
    if (rst) begin
      state_tx <= STATE_IDLE;
      state_rx <= STATE_IDLE;
    end
    else begin
      case (state_tx)
        STATE_IDLE: begin
          if (out_valid & !stall) begin
            state_tx <= STATE_HDR_DEST;
            out_char_buf <= out_char;
          end
        end
        STATE_HDR_DEST: begin
          if (c_uart_out_ready) begin
            state_tx <= STATE_HDR_SRC;
          end
        end
        STATE_HDR_SRC: begin
          if (c_uart_out_ready) begin
            state_tx <= STATE_HDR_FLAGS;
          end
        end
        STATE_HDR_FLAGS: begin
          if (c_uart_out_ready) begin
            state_tx <= STATE_XFER;
          end
        end
        STATE_XFER: begin
          if (c_uart_out_ready) begin
            state_tx <= STATE_IDLE;
          end
        end
      endcase

      case (state_rx)
        STATE_IDLE: begin
          if (c_uart_in.valid) begin
            state_rx <= STATE_HDR_SRC;
          end
        end
        STATE_HDR_SRC: begin
          if (c_uart_in.valid) begin
            state_rx <= STATE_HDR_FLAGS;
          end
        end
        STATE_HDR_FLAGS: begin
          if (c_uart_in.valid) begin
            state_rx <= STATE_XFER;
          end
        end
        STATE_XFER: begin
          if (c_uart_in.valid & in_ready) begin
            state_rx <= STATE_IDLE;
          end
        end
      endcase
    end
  end

  always_comb begin
    c_uart_out.valid = 0;
    c_uart_out.last = 0;
    c_uart_out.data = 16'h0;
    out_ready = 0;

    case (state_tx)
      STATE_IDLE: begin
        out_ready = !stall;
      end
      STATE_HDR_DEST: begin
        c_uart_out.valid = 1;
        c_uart_out.data = event_dest;
      end
      STATE_HDR_SRC: begin
        c_uart_out.valid = 1;
        c_uart_out.data = id;
      end
      STATE_HDR_FLAGS: begin
        c_uart_out.valid = 1;
        c_uart_out.data = {TYPE_EVENT, TYPE_SUB_EVENT_LAST, 10'h0};
      end
      STATE_XFER: begin
        c_uart_out.valid = 1;
        c_uart_out.data = {8'h0, out_char_buf};
        c_uart_out.last = 1;
      end
    endcase

    c_uart_in_ready = 0;
    in_valid = 0;
    in_char = 8'h0;

    case (state_rx)
      STATE_IDLE: begin
        c_uart_in_ready = 1;
      end
      STATE_HDR_SRC: begin
        c_uart_in_ready = 1;
      end
      STATE_HDR_FLAGS: begin
        c_uart_in_ready = 1;
      end
      STATE_XFER: begin
        c_uart_in_ready = in_ready;
        in_valid = c_uart_in.valid;
        in_char = c_uart_in.data[7:0];
      end
    endcase
  end
endmodule
