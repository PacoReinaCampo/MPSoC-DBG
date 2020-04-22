/* Copyright (c) 2013 by the author(s)
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
 *
 * Wishbone SLAVE Adapter for the Memory Access Module (MAM)
 *
 * This adapter is made to be inserted in front of a Wishbone SLAVE memory.
 *
 * ---------------  WB Slave  ------------------  WB Slave  ----------
 * | WB INTERCON | ========== | mam_wb_adapter | ========== | Memory |
 * ---------------    ahb3_in   ------------------   ahb3_out   ----------
 *                                   ||
 *                            wb_mam || WB Master
 *                                   ||
 *                                 -------
 *                                 | mam |
 *                                 -------
 *
 * If the global define OPTIMSOC_DEBUG_ENABLE_MAM is not set the adapter is
 * transparent (e.g. reduced to wires).
 *
 * Author(s):
 *   Philipp Wagner <philipp.wagner@tum.de>
 */

module mam_ahb3_adapter (
  wb_mam_ack_i, wb_mam_rty_i, wb_mam_err_i, wb_mam_dat_i, wb_mam_bte_o,
  wb_mam_adr_o, wb_mam_cyc_o, wb_mam_dat_o, wb_mam_sel_o, wb_mam_stb_o,
  wb_mam_we_o, wb_mam_cab_o, wb_mam_cti_o,

  // Outputs
  ahb3_in_hready_o, ahb3_in_hresp_o, ahb3_in_hwdata_o, ahb3_out_haddr_i,
  ahb3_out_htrans_i, ahb3_out_hburst_i, ahb3_out_hmastlock_i, ahb3_out_hwdata_i,
  ahb3_out_hprot_i, ahb3_out_hsel_i, ahb3_out_hwrite_i, ahb3_out_clk_i,
  ahb3_out_rst_i,
  // Inputs
  ahb3_in_haddr_i, ahb3_in_htrans_i, ahb3_in_hburst_i, ahb3_in_hmastlock_i, ahb3_in_hrdata_i,
  ahb3_in_hprot_i, ahb3_in_hsel_i, ahb3_in_hwrite_i, ahb3_in_clk_i, ahb3_in_rst_i,
  ahb3_out_hready_o, ahb3_out_hresp_o, ahb3_out_hrdata_o
);

  import optimsoc_functions::*;

  // address width
  parameter PLEN = 32;

  // data width
  parameter XLEN = 32;

  parameter USE_DEBUG = 1;

  // byte select width
  localparam SW = (XLEN == 32) ? 4 :
                  (XLEN == 16) ? 2 :
                  (XLEN ==  8) ? 1 : 'hx;

  /*
   * +--------------+--------------+
   * | word address | byte in word |
   * +--------------+--------------+
   *     WORD_AW         BYTE_AW
   *        +----- PLEN -----+
   */

  localparam BYTE_AW = SW >> 1;
  localparam WORD_AW = PLEN - BYTE_AW;

  // Wishbone SLAVE interface: input side (to the CPU etc.)
  input  [PLEN-1:0] ahb3_in_haddr_i;
  input  [     1:0] ahb3_in_htrans_i;
  input  [     2:0] ahb3_in_hburst_i;
  input             ahb3_in_hmastlock_i;
  input  [XLEN-1:0] ahb3_in_hrdata_i;
  input  [SW  -1:0] ahb3_in_hprot_i;
  input             ahb3_in_hsel_i;
  input             ahb3_in_hwrite_i;

  output            ahb3_in_hready_o;
  output            ahb3_in_hresp_o;
  output [XLEN-1:0] ahb3_in_hwdata_o;

  input             ahb3_in_clk_i;
  input             ahb3_in_rst_i;

  // Wishbone SLAVE interface: output side (to the memory)
  output [PLEN-1:0] ahb3_out_haddr_i;
  output [     1:0] ahb3_out_htrans_i;
  output [     2:0] ahb3_out_hburst_i;
  output            ahb3_out_hmastlock_i;
  output [XLEN-1:0] ahb3_out_hwdata_i;
  output [SW  -1:0] ahb3_out_hprot_i;
  output            ahb3_out_hsel_i;
  output            ahb3_out_hwrite_i;

  input             ahb3_out_hready_o;
  input             ahb3_out_hresp_o;
  input  [XLEN-1:0] ahb3_out_hrdata_o;

  output            ahb3_out_clk_i;
  output            ahb3_out_rst_i;

  // we use a common clock for all this module!
  assign ahb3_out_clk_i = ahb3_in_clk_i;
  assign ahb3_out_rst_i = ahb3_in_rst_i;

  // MAM Wishbone MASTER interface (incoming)
  input  [PLEN-1:0] wb_mam_adr_o;
  input             wb_mam_cyc_o;
  input  [XLEN-1:0] wb_mam_dat_o;
  input  [SW  -1:0] wb_mam_sel_o;
  input             wb_mam_stb_o;
  input             wb_mam_we_o;
  input             wb_mam_cab_o;
  input  [     2:0] wb_mam_cti_o;
  input  [     1:0] wb_mam_bte_o;
  output            wb_mam_ack_i;
  output            wb_mam_rty_i;
  output            wb_mam_err_i;
  output [XLEN-1:0] wb_mam_dat_i;

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
    always @(posedge ahb3_in_clk_i) begin
      if (ahb3_in_rst_i) begin
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
          if (wb_mam_cyc_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end
          else if (ahb3_in_hmastlock_i == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_CPU;
          end
          else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end

        STATE_ARB_ACCESS_MAM: begin
          grant_access_mam = 1'b1;

          if (wb_mam_cyc_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end
          else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end
        //CPU may finish cycle before switching to MAM. May need changes if instant MAM access required
        STATE_ARB_ACCESS_CPU: begin
          grant_access_cpu = 1'b1;
          if (ahb3_in_hmastlock_i == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_CPU;
          end
          else if (wb_mam_cyc_o == 1'b1) begin
            fsm_arb_state_next = STATE_ARB_ACCESS_MAM;
          end
          else begin
            fsm_arb_state_next = STATE_ARB_IDLE;
          end
        end
      endcase
    end

    // MUX of signals TO the memory
    assign ahb3_out_haddr_i     = access_cpu ? ahb3_in_haddr_i : wb_mam_adr_o;
    assign ahb3_out_htrans_i    = access_cpu ? ahb3_in_htrans_i : wb_mam_bte_o;
    assign ahb3_out_hburst_i    = access_cpu ? ahb3_in_hburst_i : wb_mam_cti_o;
    assign ahb3_out_hmastlock_i = access_cpu ? ahb3_in_hmastlock_i : wb_mam_cyc_o;
    assign ahb3_out_hwdata_i    = access_cpu ? ahb3_in_hrdata_i : wb_mam_dat_o;
    assign ahb3_out_hprot_i     = access_cpu ? ahb3_in_hprot_i : wb_mam_sel_o;
    assign ahb3_out_hsel_i      = access_cpu ? ahb3_in_hsel_i : wb_mam_stb_o;
    assign ahb3_out_hwrite_i    = access_cpu ? ahb3_in_hwrite_i : wb_mam_we_o;


    // MUX of signals FROM the memory
    assign ahb3_in_hready_o = access_cpu ? ahb3_out_hready_o : 1'b0;
    assign ahb3_in_hresp_o  = access_cpu ? ahb3_out_hresp_o : 1'b0;
    assign ahb3_in_hwdata_o = access_cpu ? ahb3_out_hrdata_o : {XLEN{1'b0}};

    assign wb_mam_ack_i = ~access_cpu ? ahb3_out_hready_o : 1'b0;
    assign wb_mam_err_i = ~access_cpu ? ahb3_out_hresp_o : 1'b0;
    assign wb_mam_dat_i = ~access_cpu ? ahb3_out_hrdata_o : {XLEN{1'b0}};
  end
  else begin
    assign ahb3_out_haddr_i     = ahb3_in_haddr_i;
    assign ahb3_out_htrans_i    = ahb3_in_htrans_i;
    assign ahb3_out_hburst_i    = ahb3_in_hburst_i;
    assign ahb3_out_hmastlock_i = ahb3_in_hmastlock_i;
    assign ahb3_out_hwdata_i    = ahb3_in_hrdata_i;
    assign ahb3_out_hprot_i     = ahb3_in_hprot_i;
    assign ahb3_out_hsel_i      = ahb3_in_hsel_i;
    assign ahb3_out_hwrite_i    = ahb3_in_hwrite_i;

    assign ahb3_in_hready_o = ahb3_out_hready_o;
    assign ahb3_in_hresp_o  = ahb3_out_hresp_o;
    assign ahb3_in_hwdata_o = ahb3_out_hrdata_o;
  end
endmodule
