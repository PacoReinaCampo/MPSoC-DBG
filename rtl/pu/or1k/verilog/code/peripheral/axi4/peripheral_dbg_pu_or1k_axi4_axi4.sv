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
//              PU-OR1K                                                       //
//              WishBone Bus Interface                                        //
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
//   Nathan Yawn <nathan.yawn@opencores.org>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

`include "peripheral_dbg_pu_or1k_defines_axi4.sv"

module peripheral_dbg_pu_or1k_axi4_axi4 (
  // Debug interface signals
  input             tck_i,
  input             rst_i,
  input      [31:0] data_i,      // Assume short words are in UPPER order bits!
  output     [31:0] data_o,
  input      [31:0] addr_i,
  input             strobe_i,
  input             rd_wrn_i,
  output reg        rdy_o,
  output            err_o,
  input      [ 2:0] word_size_i,

  // Wishbone signals
  input             axi4_clk_i,
  output     [31:0] axi4_adr_o,
  output     [31:0] axi4_dat_o,
  input      [31:0] axi4_dat_i,
  output reg        axi4_cyc_o,
  output reg        axi4_stb_o,
  output     [ 3:0] axi4_sel_o,
  output            axi4_we_o,
  input             axi4_ack_i,
  output            axi4_cab_o,
  input             axi4_err_i,
  output     [ 2:0] axi4_cti_o,
  output     [ 1:0] axi4_bte_o
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  `define STATE_IDLE 1'h0
  `define STATE_TRANSFER 1'h1

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // Registers
  reg  [ 3:0] sel_reg;
  reg  [31:0] addr_reg;  // Don't really need the two LSB, this info is in the SEL bits
  reg  [31:0] data_in_reg;  // dbg->WB
  reg  [31:0] data_out_reg;  // WB->dbg
  reg         wr_reg;
  reg         str_sync;  // This is 'active-toggle' rather than -high or -low.
  reg         rdy_sync;  // ditto, active-toggle
  reg         err_reg;

  // Sync registers. TFF indicates TCK domain, WBFF indicates axi4_clk domain
  reg         rdy_sync_tff1;
  reg         rdy_sync_tff2;
  reg         rdy_sync_tff2q;  // used to detect toggles
  reg         str_sync_axi4ff1;
  reg         str_sync_axi4ff2;
  reg         str_sync_axi4ff2q;  // used to detect toggles

  // Control Signals
  reg         data_o_en;  // latch axi4_data_i
  reg         rdy_sync_en;  // toggle the rdy_sync signal, indicate ready to TCK domain
  reg         err_en;  // latch the axi4_err_i signal

  // Internal signals
  reg  [ 3:0] be_dec;  // word_size and low-order address bits decoded to SEL bits
  wire        start_toggle;  // WB domain, indicates a toggle on the start strobe
  reg  [31:0] swapped_data_i;
  reg  [31:0] swapped_data_out;

  reg         axi4_fsm_state;
  reg         next_fsm_state;

  // TCK clock domain
  // There is no FSM here, just signal latching and clock
  // domain synchronization

  // Create byte enable signals from word_size and address (combinatorial)
`ifdef DBG_WB_LITTLE_ENDIAN
  // This uses LITTLE ENDIAN byte ordering...lowest-addressed bytes is the
  // least-significant byte of the 32-bit WB bus.
  always @(word_size_i or addr_i) begin
    case (word_size_i)
      3'h1: begin
        if (addr_i[1:0] == 2'b00) begin
          be_dec <= 4'b0001;
        end else if (addr_i[1:0] == 2'b01) begin
          be_dec <= 4'b0010;
        end else if (addr_i[1:0] == 2'b10) begin
          be_dec <= 4'b0100;
        end else begin
          be_dec <= 4'b1000;
        end
      end
      3'h2: begin
        if (addr_i[1]) begin
          be_dec <= 4'b1100;
        end else begin
          be_dec <= 4'b0011;
        end
      end
      3'h4: begin
        be_dec <= 4'b1111;
      end
      default: begin
        be_dec <= 4'b1111;  // default to 32-bit access
      end
    endcase
  end
`else
  // This is for a BIG ENDIAN CPU...lowest-addressed byte is 
  // the 8 most significant bits of the 32-bit WB bus.
  always @(word_size_i or addr_i) begin
    case (word_size_i)
      3'h1: begin
        if (addr_i[1:0] == 2'b00) begin
          be_dec <= 4'b1000;
        end else if (addr_i[1:0] == 2'b01) begin
          be_dec <= 4'b0100;
        end else if (addr_i[1:0] == 2'b10) begin
          be_dec <= 4'b0010;
        end else begin
          be_dec <= 4'b0001;
        end
      end
      3'h2: begin
        if (addr_i[1] == 1'b1) begin
          be_dec <= 4'b0011;
        end else begin
          be_dec <= 4'b1100;
        end
      end
      3'h4: begin
        be_dec <= 4'b1111;
      end
      default: begin
        be_dec <= 4'b1111;  // default to 32-bit access
      end
    endcase
  end
`endif

  // Byte- or word-swap data as necessary.  Use the non-latched be_dec signal,
  // since it and the swapped data will be latched at the same time.
  // Remember that since the data is shifted in LSB-first, shorter words
  // will be in the high-order bits. (combinatorial)
  always @(be_dec or data_i) begin
    case (be_dec)
      4'b1111: swapped_data_i <= data_i;
      4'b0011: swapped_data_i <= {16'h0, data_i[31:16]};
      4'b1100: swapped_data_i <= data_i;
      4'b0001: swapped_data_i <= {24'h0, data_i[31:24]};
      4'b0010: swapped_data_i <= {16'h0, data_i[31:24], 8'h0};
      4'b0100: swapped_data_i <= {8'h0, data_i[31:24], 16'h0};
      4'b1000: swapped_data_i <= {data_i[31:24], 24'h0};
      default: swapped_data_i <= data_i;  // Shouldn't be possible
    endcase
  end

  // Latch input data on 'start' strobe, if ready.
  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      sel_reg     <= 4'h0;
      addr_reg    <= 32'h0;
      data_in_reg <= 32'h0;
      wr_reg      <= 1'b0;
    end else if (strobe_i && rdy_o) begin
      sel_reg  <= be_dec;
      addr_reg <= addr_i;
      if (!rd_wrn_i) begin
        data_in_reg <= swapped_data_i;
      end
      wr_reg <= ~rd_wrn_i;
    end
  end

  // Create toggle-active strobe signal for clock sync.  This will start a transaction
  // on the WB once the toggle propagates to the FSM in the WB domain.
  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      str_sync <= 1'b0;
    end else if (strobe_i && rdy_o) begin
      str_sync <= ~str_sync;
    end
  end

  // Create rdy_o output.  Set on reset, clear on strobe (if set), set on input toggle
  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      rdy_sync_tff1  <= 1'b0;
      rdy_sync_tff2  <= 1'b0;
      rdy_sync_tff2q <= 1'b0;
      rdy_o          <= 1'b1;
    end else begin
      rdy_sync_tff1  <= rdy_sync;  // Synchronize the ready signal across clock domains
      rdy_sync_tff2  <= rdy_sync_tff1;
      rdy_sync_tff2q <= rdy_sync_tff2;  // used to detect toggles

      if (strobe_i && rdy_o) begin
        rdy_o <= 1'b0;
      end else if (rdy_sync_tff2 != rdy_sync_tff2q) begin
        rdy_o <= 1'b1;
      end
    end
  end

  // Direct assignments, unsynchronized
  assign axi4_dat_o = data_in_reg;
  assign axi4_we_o  = wr_reg;
  assign axi4_adr_o = addr_reg;
  assign axi4_sel_o = sel_reg;

  assign data_o   = data_out_reg;
  assign err_o    = err_reg;

  assign axi4_cti_o = 3'h0;
  assign axi4_bte_o = 2'h0;
  assign axi4_cab_o = 1'b0;

  // Wishbone clock domain

  // synchronize the start strobe
  always @(posedge axi4_clk_i or posedge rst_i) begin
    if (rst_i) begin
      str_sync_axi4ff1  <= 1'b0;
      str_sync_axi4ff2  <= 1'b0;
      str_sync_axi4ff2q <= 1'b0;
    end else begin
      str_sync_axi4ff1  <= str_sync;
      str_sync_axi4ff2  <= str_sync_axi4ff1;
      str_sync_axi4ff2q <= str_sync_axi4ff2;  // used to detect toggles
    end
  end

  assign start_toggle = (str_sync_axi4ff2 != str_sync_axi4ff2q);

  // Error indicator register
  always @(posedge axi4_clk_i or posedge rst_i) begin
    if (rst_i) begin
      err_reg <= 1'b0;
    end else if (err_en) begin
      err_reg <= axi4_err_i;
    end
  end

  // Byte- or word-swap the WB->dbg data, as necessary (combinatorial)
  // We assume bits not required by SEL are don't care.  We reuse assignments
  // where possible to keep the MUX smaller.  (combinatorial)
  always @(sel_reg or axi4_dat_i) begin
    case (sel_reg)
      4'b1111: swapped_data_out <= axi4_dat_i;
      4'b0011: swapped_data_out <= axi4_dat_i;
      4'b1100: swapped_data_out <= {16'h0, axi4_dat_i[31:16]};
      4'b0001: swapped_data_out <= axi4_dat_i;
      4'b0010: swapped_data_out <= {24'h0, axi4_dat_i[15:8]};
      4'b0100: swapped_data_out <= {16'h0, axi4_dat_i[31:16]};
      4'b1000: swapped_data_out <= {24'h0, axi4_dat_i[31:24]};
      default: swapped_data_out <= axi4_dat_i;  // Shouldn't be possible
    endcase
  end

  // WB->dbg data register
  always @(posedge axi4_clk_i or posedge rst_i) begin
    if (rst_i) begin
      data_out_reg <= 32'h0;
    end else if (data_o_en) begin
      data_out_reg <= swapped_data_out;
    end
  end

  // Create a toggle-active ready signal to send to the TCK domain
  always @(posedge axi4_clk_i or posedge rst_i) begin
    if (rst_i) begin
      rdy_sync <= 1'b0;
    end else if (rdy_sync_en) begin
      rdy_sync <= ~rdy_sync;
    end
  end

  // Small state machine to create WB accesses
  // Not much more that an 'in_progress' bit, but easier
  // to read.  Deals with single-cycle and multi-cycle
  // accesses.

  // Sequential bit
  always @(posedge axi4_clk_i or posedge rst_i) begin
    if (rst_i) begin
      axi4_fsm_state <= `STATE_IDLE;
    end else begin
      axi4_fsm_state <= next_fsm_state;
    end
  end

  // Determination of next state (combinatorial)
  always @(axi4_fsm_state or start_toggle or axi4_ack_i or axi4_err_i) begin
    case (axi4_fsm_state)
      `STATE_IDLE: begin
        if (start_toggle && !(axi4_ack_i || axi4_err_i)) begin
          next_fsm_state <= `STATE_TRANSFER;  // Don't go to next state for 1-cycle transfer
        end else begin
          next_fsm_state <= `STATE_IDLE;
        end
      end
      `STATE_TRANSFER: begin
        if (axi4_ack_i || axi4_err_i) begin
          next_fsm_state <= `STATE_IDLE;
        end else begin
          next_fsm_state <= `STATE_TRANSFER;
        end
      end
    endcase
  end

  // Outputs of state machine (combinatorial)
  always @(axi4_fsm_state or start_toggle or axi4_ack_i or axi4_err_i or wr_reg) begin
    rdy_sync_en <= 1'b0;
    err_en      <= 1'b0;
    data_o_en   <= 1'b0;
    axi4_cyc_o    <= 1'b0;
    axi4_stb_o    <= 1'b0;

    case (axi4_fsm_state)
      `STATE_IDLE: begin
        if (start_toggle) begin
          axi4_cyc_o <= 1'b1;
          axi4_stb_o <= 1'b1;
          if (axi4_ack_i || axi4_err_i) begin
            err_en      <= 1'b1;
            rdy_sync_en <= 1'b1;
          end
          if (axi4_ack_i && !wr_reg) begin
            data_o_en <= 1'b1;
          end
        end
      end
      `STATE_TRANSFER: begin
        axi4_cyc_o <= 1'b1;
        axi4_stb_o <= 1'b1;
        if (axi4_ack_i) begin
          err_en      <= 1'b1;
          data_o_en   <= 1'b1;
          rdy_sync_en <= 1'b1;
        end else if (axi4_err_i) begin
          err_en      <= 1'b1;
          rdy_sync_en <= 1'b1;
        end
      end
    endcase
  end
endmodule
