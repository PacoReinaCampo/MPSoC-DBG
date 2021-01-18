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

import optimsoc_functions::*;

module mam_bb_adapter #(
  // address width
  parameter AW = 32,

  // data width
  parameter DW = 32,

  parameter USE_DEBUG = 1,

  // byte select width
  localparam SW = (DW == 32) ? 4 :
                  (DW == 16) ? 2 :
                  (DW ==  8) ? 1 : 'hx,

  /*
   * +--------------+--------------+
   * | word address | byte in word |
   * +--------------+--------------+
   *     WORD_AW         BYTE_AW
   *        +----- AW -----+
   */

  localparam BYTE_AW = SW >> 1,
  localparam WORD_AW = AW - BYTE_AW
)
  (
    // Blackbone SLAVE interface: input side (to the CPU etc.)
    input  [AW-1:0] bb_in_addr_i,
    input  [DW-1:0] bb_in_din_i,
    input           bb_in_en_i,
    input           bb_in_we_i,

    output [DW-1:0] bb_in_dout_o,

    input           bb_in_clk_i,
    input           bb_in_rst_i,

    // Blackbone SLAVE interface: output side (to the memory)
    output [AW-1:0] bb_out_addr_i,
    output [DW-1:0] bb_out_din_i,
    output          bb_out_en_i,
    output          bb_out_we_i,

    input [DW-1:0]  bb_out_dout_o,

    output          bb_out_clk_i,
    output          bb_out_rst_i,

    // MAM Blackbone MASTER interface (incoming)
    input  [AW-1:0] bb_mam_addr_o,
    input  [DW-1:0] bb_mam_din_o,
    input           bb_mam_en_o,
    input           bb_mam_we_o,

    output [DW-1:0] bb_mam_dout_i
  );

  // we use a common clock for all this module!
  assign bb_out_clk_i = bb_in_clk_i;
  assign bb_out_rst_i = bb_in_rst_i;

  if (USE_DEBUG == 1) begin

    localparam STATE_ARB_WIDTH = 2;
    localparam STATE_ARB_IDLE = 0;
    localparam STATE_ARB_ACCESS_MAM = 1;
    localparam STATE_ARB_ACCESS_CPU = 2;

    reg [STATE_ARB_WIDTH-1:0] fsm_arb_state;
    reg [STATE_ARB_WIDTH-1:0] fsm_arb_state_next;

    reg grant_access_cpu;
    reg grant_access_mam;
    reg access_cpu;

    // arbiter FSM: MAM has higher priority than CPU
    always @(posedge bb_in_clk_i) begin
      if (bb_in_rst_i) begin
        fsm_arb_state <= STATE_ARB_IDLE;
      end
      else begin
        fsm_arb_state <= fsm_arb_state_next;

        if (grant_access_cpu) begin
          access_cpu <= 1'b1;
        end
        else if (grant_access_mam) begin
          access_cpu <= 1'b0;
        end
      end
    end

    always @(*) begin
      grant_access_cpu = 1'b0;
      grant_access_mam = 1'b0;
      fsm_arb_state_next = STATE_ARB_IDLE;

      case (fsm_arb_state)
        STATE_ARB_IDLE: begin
          if (bb_mam_en_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end
          else if (bb_in_en_i == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_CPU;
          end
          else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end

        STATE_ARB_ACCESS_MAM: begin
          grant_access_mam = 1'b1;

          if (bb_mam_en_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end
          else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end
        //CPU may finish cycle before switching to MAM. May need changes if instant MAM access required
        STATE_ARB_ACCESS_CPU: begin
          grant_access_cpu = 1'b1;
          if (bb_in_en_i == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_CPU;
          end
          else if (bb_mam_en_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end
          else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end
      endcase
    end

    // MUX of signals TO the memory
    assign bb_out_addr_i = access_cpu ? bb_in_addr_i : bb_mam_addr_o;
    assign bb_out_din_i  = access_cpu ? bb_in_din_i  : bb_mam_din_o;
    assign bb_out_en_i   = access_cpu ? bb_in_en_i   : bb_mam_en_o;
    assign bb_out_we_i   = access_cpu ? bb_in_we_i   : bb_mam_we_o;
    // MUX of signals FROM the memory
    assign bb_in_dout_o = access_cpu ? bb_out_dout_o : {DW{1'b0}};

    assign bb_mam_dout_i = ~access_cpu ? bb_out_dout_o : {DW{1'b0}};
  end
  else begin
    assign bb_out_addr_i = bb_in_addr_i;
    assign bb_out_din_i  = bb_in_din_i;
    assign bb_out_en_i   = bb_in_en_i;
    assign bb_out_we_i   = bb_in_we_i;

    assign bb_in_dout_o = bb_out_dout_o;
  end
endmodule
