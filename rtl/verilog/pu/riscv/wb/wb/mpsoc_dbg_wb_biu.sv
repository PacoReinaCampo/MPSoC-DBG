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
//              WishBone Bus Interface                                        //
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
 *   Nathan Yawn <nathan.yawn@opencores.org>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

// Top module
module mpsoc_dbg_wb_biu #(
  parameter LITTLE_ENDIAN = 1,
  parameter ADDR_WIDTH    = 32,
  parameter DATA_WIDTH    = 32
)
  (
    // Debug interface signals
    input                         biu_clk,
    input                         biu_rst,
    input        [DATA_WIDTH-1:0] biu_di,
    output       [DATA_WIDTH-1:0] biu_do,
    input        [ADDR_WIDTH-1:0] biu_addr,
    input                         biu_strb,
    input                         biu_rw,
    output reg                    biu_rdy,
    output                        biu_err,
    input        [           3:0] biu_word_size,

    // Wishbone signals
    input                         wb_clk_i,
    output reg                    wb_cyc_o,
    output reg                    wb_stb_o,
    output reg                    wb_we_o,
    output     [             2:0] wb_cti_o,
    output     [             1:0] wb_bte_o,
    output     [ADDR_WIDTH  -1:0] wb_adr_o,
    output     [DATA_WIDTH/8-1:0] wb_sel_o,
    output     [DATA_WIDTH  -1:0] wb_dat_o,
    input      [DATA_WIDTH  -1:0] wb_dat_i,
    input                         wb_ack_i,
    input                         wb_err_i
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  localparam IDLE     = 1'b1;
  localparam TRANSFER = 1'b0;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [           3:0] sel_reg;
  logic [ADDR_WIDTH-1:0] addr_reg;
  logic [DATA_WIDTH-1:0] data_in_reg;   // dbg->WB
  logic [DATA_WIDTH-1:0] data_out_reg;  // WB->dbg
  logic                  wr_reg;
  logic                  str_sync;  // This is 'active-toggle' rather than -high or -low.
  logic                  rdy_sync;  // ditto, active-toggle
  logic                  err_reg;

  // Sync registers.  TFF indicates TCK domain, WBFF indicates wb_clk domain
  logic [1:0] wb_rst_sync;
  logic       wb_rst;
  logic       rdy_sync_tff1;
  logic       rdy_sync_tff2;
  logic       rdy_sync_tff2q;   // used to detect toggles
  logic       str_sync_wbff1;
  logic       str_sync_wbff2;
  logic       str_sync_wbff2q;  // used to detect toggles

  // Control Signals
  logic wb_resp;  // WB response received (either ACK or ERR)

  // Internal signals
  logic [           3:0] be_dec;        // word_size and low-order address bits decoded to SEL bits
  logic                  start_toggle;  // WB domain, indicates a toggle on the start strobe
  logic [DATA_WIDTH-1:0] swapped_data_in;
  logic [DATA_WIDTH-1:0] swapped_data_out;

  //WB FSM
  logic wb_fsm_state;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  //////////////////////////////////////////////////////
  // TCK clock domain
  //

  // There is no FSM here, just signal latching and clock domain synchronization

  // Create byte enable signals from word_size and address (combinatorial)
  always @(*) begin
    case (biu_word_size)
      3'h1 : case (biu_addr[1:0])
        2'b00 : be_dec = LITTLE_ENDIAN ? 4'b0001 : 4'b1000;
        2'b01 : be_dec = LITTLE_ENDIAN ? 4'b0010 : 4'b0100;
        2'b10 : be_dec = LITTLE_ENDIAN ? 4'b0100 : 4'b0010;
        2'b11 : be_dec = LITTLE_ENDIAN ? 4'b1000 : 4'b0001;
      endcase
      3'h2 : case (biu_addr[1])
        1'b0  : be_dec = LITTLE_ENDIAN ? 4'b0011 : 4'b1100;
        1'b1  : be_dec = LITTLE_ENDIAN ? 4'b1100 : 4'b0011;
      endcase
      default : be_dec = 4'b1111;  // default to 32-bit access
    endcase 
  end

  // Byte- or word-swap data as necessary.  Use the non-latched be_dec signal,
  // since it and the swapped data will be latched at the same time.
  // Remember that since the data is shifted in LSB-first, shorter words
  // will be in the high-order bits. (combinatorial)
  always @(*) begin
    case (be_dec)
      4'b1111: swapped_data_in =  biu_di;
      4'b0011: swapped_data_in = {16'h0,biu_di[31:16]};
      4'b1100: swapped_data_in =  biu_di;
      4'b0001: swapped_data_in = {24'h0, biu_di[31:24]};
      4'b0010: swapped_data_in = {16'h0, biu_di[31:24], 8'h0};
      4'b0100: swapped_data_in = {8'h0, biu_di[31:24], 16'h0};
      4'b1000: swapped_data_in = {biu_di[31:24], 24'h0};
      default: swapped_data_in =  biu_di;  // Shouldn't be possible
    endcase
  end

  // Latch input data on 'start' strobe, if ready.
  always @(posedge biu_clk,posedge biu_rst) begin
    if(biu_rst) begin
      sel_reg     <= 'h0;
      addr_reg    <= 'h0;
      data_in_reg <= 'h0;
      wr_reg      <= 'b0;
    end
    else if (biu_strb && biu_rdy) begin
      sel_reg  <=  be_dec;
      addr_reg <=  biu_addr;
      wr_reg   <= ~biu_rw;
      if (!biu_rw) data_in_reg <= swapped_data_in;
    end 
  end

  // Create toggle-active strobe signal for clock sync.  This will start a transaction
  // on the WB once the toggle propagates to the FSM in the WB domain.
  always @(posedge biu_clk,posedge biu_rst) begin
    if      (biu_rst            ) str_sync <= 1'b0;
    else if (biu_strb && biu_rdy) str_sync <= ~str_sync;
  end

  // Create biu_rdy output.  Set on reset, clear on strobe (if set), set on input toggle
  always @ (posedge biu_clk,posedge biu_rst) begin
    if(biu_rst) begin
      rdy_sync_tff1  <= 1'b0;
      rdy_sync_tff2  <= 1'b0;
      rdy_sync_tff2q <= 1'b0;
      biu_rdy        <= 1'b1;
    end
    else begin  
      rdy_sync_tff1  <= rdy_sync;       // Synchronize the ready signal across clock domains
      rdy_sync_tff2  <= rdy_sync_tff1;
      rdy_sync_tff2q <= rdy_sync_tff2;  // used to detect toggles

      if      (biu_strb && biu_rdy            ) biu_rdy <= 1'b0;
      else if (rdy_sync_tff2 != rdy_sync_tff2q) biu_rdy <= 1'b1;
    end
  end

  // Direct assignments, unsynchronized
  assign wb_dat_o = data_in_reg;
  assign wb_we_o  = wr_reg;
  assign wb_adr_o = addr_reg;
  assign wb_sel_o = sel_reg;

  assign biu_do   = data_out_reg;
  assign biu_err  = err_reg;

  assign wb_cti_o = 3'h0;
  assign wb_bte_o = 2'h0;

  ///////////////////////////////////////////////////////
  // Wishbone clock domain
  //

  // synchronize asynchronous active high reset
  always @(posedge wb_clk_i,posedge biu_rst) begin
    if (biu_rst) wb_rst_sync <= {$bits(wb_rst_sync){1'b1}};
    else         wb_rst_sync <= {1'b0,wb_rst_sync[$bits(wb_rst_sync)-1:1]};
  end

  assign wb_rst = wb_rst_sync[0];

  // synchronize the start strobe
  always @ (posedge wb_clk_i,posedge wb_rst) begin
    if(wb_rst) begin
      str_sync_wbff1  <= 1'b0;
      str_sync_wbff2  <= 1'b0;
      str_sync_wbff2q <= 1'b0;      
    end
    else begin
      str_sync_wbff1 <= str_sync;
      str_sync_wbff2 <= str_sync_wbff1;
      str_sync_wbff2q <= str_sync_wbff2;  // used to detect toggles
    end
  end

  assign start_toggle = (str_sync_wbff2 != str_sync_wbff2q);

  // Error indicator register
  always @(posedge wb_clk_i,posedge wb_rst) begin
    if      (wb_rst ) err_reg <= 1'b0;
    else if (wb_resp) err_reg <= wb_err_i; 
  end

  // Byte- or word-swap the WB->dbg data, as necessary (combinatorial)
  // We assume bits not required by SEL are don't care.  We reuse assignments
  // where possible to keep the MUX smaller.  (combinatorial)
  always @(*) begin
    case (sel_reg)
      4'b1111: swapped_data_out = wb_dat_i;
      4'b0011: swapped_data_out = wb_dat_i;
      4'b1100: swapped_data_out = {16'h0, wb_dat_i[31:16]};
      4'b0001: swapped_data_out = wb_dat_i;
      4'b0010: swapped_data_out = {24'h0, wb_dat_i[15:8]};
      4'b0100: swapped_data_out = {16'h0, wb_dat_i[31:16]};
      4'b1000: swapped_data_out = {24'h0, wb_dat_i[31:24]};
      default: swapped_data_out = wb_dat_i;  // Shouldn't be possible
    endcase
  end

  // WB->dbg data register
  always @(posedge wb_clk_i,posedge wb_rst) begin
    if      (wb_rst ) data_out_reg <= 'h0;
    else if (wb_resp) data_out_reg <= swapped_data_out;
  end

  // Create a toggle-active ready signal to send to the TCK domain
  always @(posedge wb_clk_i,posedge wb_rst) begin
    if      (wb_rst ) rdy_sync <= 1'b0;
    else if (wb_resp) rdy_sync <= ~rdy_sync;
  end

  // Small state machine to create WB accesses
  // Not much more that an 'in_progress' bit, but easier to read
  // Handles single-cycle and multi-cycle accesses.

  assign wb_resp = wb_ack_i | wb_err_i;

  always @(posedge wb_clk_i,posedge wb_rst) begin
    if (wb_rst) begin
      wb_cyc_o <= 'b0;
      wb_stb_o <= 'b0;
      wb_fsm_state <= IDLE;
    end
    else begin
      case (wb_fsm_state)
        IDLE    : if (start_toggle) begin
          wb_cyc_o     <= 1'b1;
          wb_stb_o     <= 1'b1;
          wb_fsm_state <= TRANSFER;
        end
        TRANSFER: if (wb_resp) begin
          wb_cyc_o     <= 1'b0;
          wb_stb_o     <= 1'b0;
          wb_fsm_state <= IDLE;
        end
      endcase
    end
  end
endmodule
