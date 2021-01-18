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
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

import dii_package::dii_flit;

module osd_regaccess_demux (
  input clk,
  input rst,

  input  dii_flit in,

  output dii_flit out_reg,
  output dii_flit out_bypass,

  output logic in_ready,

  input out_reg_ready,
  input out_bypass_ready
);

  typedef struct packed {
    logic [15:0] data;
    logic last;
    logic valid;
  } bufdata;

  bufdata buf_reg[3];

  logic [2:0] buf_reg_is_regaccess;
  logic [2:0] buf_reg_is_bypass;

  logic do_tag, mark_bypass, mark_regaccess;

  logic pkg_is_bypass, pkg_is_regaccess;

  logic keep_1, keep_2;

  logic no_buf_entry_is_tagged;

  assign do_tag = buf_reg[2].valid & buf_reg[1].valid & buf_reg[0].valid &
                 (!buf_reg_is_regaccess[2] & !buf_reg_is_bypass[2]) &
                 (!buf_reg_is_regaccess[1] & !buf_reg_is_bypass[1]) &
                 (!buf_reg_is_regaccess[0] & !buf_reg_is_bypass[0]);

  assign mark_bypass    = do_tag & (buf_reg[0].data[15:14] != 2'b00);
  assign mark_regaccess = do_tag & (buf_reg[0].data[15:14] == 2'b00);

  always_ff @(posedge clk) begin
    if (rst) begin
      pkg_is_bypass    <= 0;
      pkg_is_regaccess <= 0;
    end
    else begin
      pkg_is_bypass <= (pkg_is_bypass | mark_bypass) &
                      !(in.last & in.valid & in_ready) &
                      !(buf_reg[0].last & buf_reg[0].valid);

      pkg_is_regaccess <= (pkg_is_regaccess | mark_regaccess) &
                         !(in.last & in.valid & in_ready) &
                         !(buf_reg[0].last & buf_reg[0].valid);
    end
  end

  assign keep_1 = !do_tag & buf_reg[1].valid &
                  !(buf_reg_is_bypass[1] | buf_reg_is_regaccess[1]) & keep_2;

  assign keep_2 = !do_tag & buf_reg[2].valid &
                  !(buf_reg_is_bypass[2] | buf_reg_is_regaccess[2]);

  always_ff @(posedge clk) begin
    if (rst) begin
      buf_reg[0].valid        <= 0;
      buf_reg_is_regaccess[0] <= 0;
      buf_reg_is_bypass[0]    <= 0;

      buf_reg[1].valid        <= 0;
      buf_reg_is_regaccess[1] <= 0;
      buf_reg_is_bypass[1]    <= 0;

      buf_reg[2].valid        <= 0;
      buf_reg_is_regaccess[2] <= 0;
      buf_reg_is_bypass[2]    <= 0;
    end
    else begin
      if (in_ready) begin
        buf_reg[0].data <= in.data;
        buf_reg[0].last <= in.last;
        buf_reg[0].valid <= in.valid & in_ready;
        if (buf_reg[0].valid & !buf_reg[0].last) begin
          buf_reg_is_regaccess[0] <= pkg_is_regaccess | mark_regaccess;
          buf_reg_is_bypass[0] <= pkg_is_bypass | mark_bypass;
        end
        else begin
          buf_reg_is_regaccess[0] <= pkg_is_regaccess;
          buf_reg_is_bypass[0] <= pkg_is_bypass;
        end

        if (!keep_1) begin
          buf_reg[1] <= buf_reg[0];
          buf_reg_is_regaccess[1] <= buf_reg_is_regaccess[0] | mark_regaccess;
          buf_reg_is_bypass[1] <= buf_reg_is_bypass[0] | mark_bypass;
        end
        else begin
          buf_reg_is_regaccess[1] <= buf_reg_is_regaccess[1] | mark_regaccess;
          buf_reg_is_bypass[1] <= buf_reg_is_bypass[1] | mark_bypass;
        end

        if (!keep_2) begin
          buf_reg[2] <= buf_reg[1];
          buf_reg_is_regaccess[2] <= buf_reg_is_regaccess[1] | mark_regaccess;
          buf_reg_is_bypass[2] <= buf_reg_is_bypass[1] | mark_bypass;
        end
        else begin
          buf_reg_is_regaccess[2] <= buf_reg_is_regaccess[2] | mark_regaccess;
          buf_reg_is_bypass[2] <= buf_reg_is_bypass[2] | mark_bypass;
        end
      end
    end
  end

  // Output data
  assign out_reg.data  = buf_reg[2].data;
  assign out_reg.last  = buf_reg[2].last;
  assign out_reg.valid = buf_reg[2].valid &
                        (buf_reg_is_regaccess[2] | mark_regaccess);

  assign out_bypass.data  = buf_reg[2].data;
  assign out_bypass.last  = buf_reg[2].last;
  assign out_bypass.valid = buf_reg[2].valid &
                           (buf_reg_is_bypass[2] | mark_bypass);

  assign no_buf_entry_is_tagged = ~do_tag & ~((|buf_reg_is_regaccess) | (|buf_reg_is_bypass));

  assign in_ready = (out_bypass_ready & out_reg_ready) |
                    (out_bypass_ready & (buf_reg_is_bypass[2] | mark_bypass)) |
                    (out_reg_ready & (buf_reg_is_regaccess[2] | mark_regaccess)) |
                    no_buf_entry_is_tagged;
endmodule
