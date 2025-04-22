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
// Copyright (c) 2018-2019 by the author(s)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//   Philipp Wagner <philipp.wagner@tum.de>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

import soc_optimsoc_functions::*;

module peripheral_dbg_soc_mam_adapter_ahb4 #(
  // address width
  parameter PLEN = 32,

  // data width
  parameter XLEN = 32,

  parameter USE_DEBUG = 1,

  // byte select width
  localparam SW = (XLEN == 32) ? 4 : (XLEN == 16) ? 2 : (XLEN == 8) ? 1 : 'hx,

  // +--------------+--------------+
  // | word address | byte in word |
  // +--------------+--------------+
  //     WORD_AW         BYTE_AW
  //        +---- PLEN ----+

  localparam BYTE_AW = SW >> 1,
  localparam WORD_AW = PLEN - BYTE_AW
) (
  // AHB4 SLAVE interface: input side (to the CPU etc.)
  input            ahb4_in_hsel_i,
  input [PLEN-1:0] ahb4_in_haddr_i,
  input [XLEN-1:0] ahb4_in_hwdata_i,
  input            ahb4_in_hwrite_i,
  input [     2:0] ahb4_in_hsize_i,
  input [     2:0] ahb4_in_hburst_i,
  input [SW  -1:0] ahb4_in_hprot_i,
  input [     1:0] ahb4_in_htrans_i,
  input            ahb4_in_hmastlock_i,

  output [XLEN-1:0] ahb4_in_hrdata_o,
  output            ahb4_in_hready_o,
  output            ahb4_in_hresp_o,

  input ahb4_in_clk_i,
  input ahb4_in_rst_i,

  // AHB4 SLAVE interface: output side (to the memory)
  output            ahb4_out_hsel_i,
  output [PLEN-1:0] ahb4_out_haddr_i,
  output [XLEN-1:0] ahb4_out_hwdata_i,
  output            ahb4_out_hwrite_i,
  output [     2:0] ahb4_out_hsize_i,
  output [     2:0] ahb4_out_hburst_i,
  output [SW  -1:0] ahb4_out_hprot_i,
  output [     1:0] ahb4_out_htrans_i,
  output            ahb4_out_hmastlock_i,

  input [XLEN-1:0] ahb4_out_hrdata_o,
  input            ahb4_out_hready_o,
  input            ahb4_out_hresp_o,

  output ahb4_out_clk_i,
  output ahb4_out_rst_i,

  // MAM AHB4 MASTER interface (incoming)
  input            ahb4_mam_hsel_o,
  input [PLEN-1:0] ahb4_mam_haddr_o,
  input [XLEN-1:0] ahb4_mam_hwdata_o,
  input            ahb4_mam_hwrite_o,
  input [     2:0] ahb4_mam_hsize_o,
  input [     2:0] ahb4_mam_hburst_o,
  input [SW  -1:0] ahb4_mam_hprot_o,
  input [     1:0] ahb4_mam_htrans_o,
  input            ahb4_mam_hmastlock_o,

  output [XLEN-1:0] ahb4_mam_hrdata_i,
  output            ahb4_mam_hready_i,
  output            ahb4_mam_hresp_i
);

  // we use a common clock for all this module!
  assign ahb4_out_clk_i = ahb4_in_clk_i;
  assign ahb4_out_rst_i = ahb4_in_rst_i;

  if (USE_DEBUG == 1) begin

    localparam STATE_ARB_WIDTH = 2;
    localparam STATE_ARB_IDLE = 0;
    localparam STATE_ARB_ACCESS_MAM = 1;
    localparam STATE_ARB_ACCESS_CPU = 2;

    reg [STATE_ARB_WIDTH-1:0] fsm_arb_state;
    reg [STATE_ARB_WIDTH-1:0] fsm_arb_state_next;

    reg                       grant_access_cpu;
    reg                       grant_access_mam;
    reg                       access_cpu;

    // arbiter FSM: MAM has higher priority than CPU
    always @(posedge ahb4_in_clk_i) begin
      if (ahb4_in_rst_i) begin
        fsm_arb_state <= STATE_ARB_IDLE;
      end else begin
        fsm_arb_state <= fsm_arb_state_next;

        if (grant_access_cpu) begin
          access_cpu <= 1'b1;
        end else if (grant_access_mam) begin
          access_cpu <= 1'b0;
        end
      end
    end

    always @(*) begin
      grant_access_cpu   = 1'b0;
      grant_access_mam   = 1'b0;
      fsm_arb_state_next = STATE_ARB_IDLE;

      case (fsm_arb_state)
        STATE_ARB_IDLE: begin
          if (ahb4_mam_hmastlock_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end else if (ahb4_in_hmastlock_i == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_CPU;
          end else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end

        STATE_ARB_ACCESS_MAM: begin
          grant_access_mam = 1'b1;

          if (ahb4_mam_hmastlock_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end
        // CPU may finish cycle before switching to MAM. May need changes if instant MAM access required
        STATE_ARB_ACCESS_CPU: begin
          grant_access_cpu = 1'b1;
          if (ahb4_in_hmastlock_i == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_CPU;
          end else if (ahb4_mam_hmastlock_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end
      endcase
    end

    // MUX of signals TO the memory
    assign ahb4_out_hsel_i      = access_cpu ? ahb4_in_hsel_i : ahb4_mam_hsel_o;
    assign ahb4_out_haddr_i     = access_cpu ? ahb4_in_haddr_i : ahb4_mam_haddr_o;
    assign ahb4_out_hwdata_i    = access_cpu ? ahb4_in_hwdata_i : ahb4_mam_hwdata_o;
    assign ahb4_out_hwrite_i    = access_cpu ? ahb4_in_hwrite_i : ahb4_mam_hwrite_o;
    assign ahb4_out_hburst_i    = access_cpu ? ahb4_in_hburst_i : ahb4_mam_hburst_o;
    assign ahb4_out_hprot_i     = access_cpu ? ahb4_in_hprot_i : ahb4_mam_hprot_o;
    assign ahb4_out_htrans_i    = access_cpu ? ahb4_in_htrans_i : ahb4_mam_htrans_o;
    assign ahb4_out_hmastlock_i = access_cpu ? ahb4_in_hmastlock_i : ahb4_mam_hmastlock_o;

    // MUX of signals FROM the memory
    assign ahb4_in_hrdata_o     = access_cpu ? ahb4_out_hrdata_o : {XLEN{1'b0}};
    assign ahb4_in_hready_o     = access_cpu ? ahb4_out_hready_o : 1'b0;
    assign ahb4_in_hresp_o      = access_cpu ? ahb4_out_hresp_o : 1'b0;

    assign ahb4_mam_hrdata_i    = ~access_cpu ? ahb4_out_hrdata_o : {XLEN{1'b0}};
    assign ahb4_mam_hready_i    = ~access_cpu ? ahb4_out_hready_o : 1'b0;
    assign ahb4_mam_hresp_i     = ~access_cpu ? ahb4_out_hresp_o : 1'b0;
  end else begin
    assign ahb4_out_hsel_i      = ahb4_in_hsel_i;
    assign ahb4_out_haddr_i     = ahb4_in_haddr_i;
    assign ahb4_out_hwdata_i    = ahb4_in_hwdata_i;
    assign ahb4_out_htrans_i    = ahb4_in_htrans_i;
    assign ahb4_out_hburst_i    = ahb4_in_hburst_i;
    assign ahb4_out_hprot_i     = ahb4_in_hprot_i;
    assign ahb4_out_hwrite_i    = ahb4_in_hwrite_i;
    assign ahb4_out_hmastlock_i = ahb4_in_hmastlock_i;

    assign ahb4_in_hrdata_o     = ahb4_out_hrdata_o;
    assign ahb4_in_hready_o     = ahb4_out_hready_o;
    assign ahb4_in_hresp_o      = ahb4_out_hresp_o;
  end
endmodule
