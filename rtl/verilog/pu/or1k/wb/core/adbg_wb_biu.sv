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

`include "adbg_wb_defines.sv"

module adbg_wb_biu (
  // Debug interface signals
  input         tck_i,
  input         rst_i,
  input  [31:0] data_i,  // Assume short words are in UPPER order bits!
  output [31:0] data_o,
  input  [31:0] addr_i,
  input         strobe_i,
  input         rd_wrn_i,
  output        rdy_o,
  output        err_o,
  input  [ 2:0] word_size_i,

  // Wishbone signals
  input         wb_clk_i,
  output [31:0] wb_adr_o,
  output [31:0] wb_dat_o,
  input  [31:0] wb_dat_i,
  output        wb_cyc_o,
  output        wb_stb_o,
  output [ 3:0] wb_sel_o,
  output        wb_we_o,
  input         wb_ack_i,
  output        wb_cab_o,
  input         wb_err_i,
  output [ 2:0] wb_cti_o,
  output [ 1:0] wb_bte_o
);

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  `define STATE_IDLE     1'h0
  `define STATE_TRANSFER 1'h1

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  wire [31:0]  data_o;
  reg          rdy_o;
  wire         err_o;

  wire [31:0]  wb_adr_o;
  reg          wb_cyc_o;
  reg          wb_stb_o;
  wire [31:0]  wb_dat_o;
  wire [ 3:0]  wb_sel_o;
  wire         wb_we_o;
  wire         wb_cab_o;
  wire [ 2:0]  wb_cti_o;
  wire [ 1:0]  wb_bte_o;

  // Registers
  reg [ 3:0]   sel_reg;
  reg [31:0]   addr_reg;  // Don't really need the two LSB, this info is in the SEL bits
  reg [31:0]   data_in_reg;  // dbg->WB
  reg [31:0]   data_out_reg;  // WB->dbg
  reg          wr_reg;
  reg          str_sync;  // This is 'active-toggle' rather than -high or -low.
  reg          rdy_sync;  // ditto, active-toggle
  reg          err_reg;

  // Sync registers. TFF indicates TCK domain, WBFF indicates wb_clk domain
  reg    rdy_sync_tff1;
  reg    rdy_sync_tff2;
  reg    rdy_sync_tff2q;  // used to detect toggles
  reg    str_sync_wbff1;
  reg    str_sync_wbff2;
  reg    str_sync_wbff2q;  // used to detect toggles

  // Control Signals
  reg    data_o_en;    // latch wb_data_i
  reg    rdy_sync_en;  // toggle the rdy_sync signal, indicate ready to TCK domain
  reg    err_en;       // latch the wb_err_i signal

  // Internal signals
  reg [ 3:0]   be_dec;  // word_size and low-order address bits decoded to SEL bits
  wire         start_toggle;  // WB domain, indicates a toggle on the start strobe
  reg [31:0]   swapped_data_i;
  reg [31:0]   swapped_data_out;

  reg wb_fsm_state;
  reg next_fsm_state;

  // TCK clock domain
  // There is no FSM here, just signal latching and clock
  // domain synchronization

  // Create byte enable signals from word_size and address (combinatorial)
  `ifdef DBG_WB_LITTLE_ENDIAN
  // This uses LITTLE ENDIAN byte ordering...lowest-addressed bytes is the
  // least-significant byte of the 32-bit WB bus.
  always @ (word_size_i or addr_i) begin
    case (word_size_i)
      3'h1 :  begin
        if(addr_i[1:0] == 2'b00) be_dec <= 4'b0001;
        else if(addr_i[1:0] == 2'b01) be_dec <= 4'b0010;
        else if(addr_i[1:0] == 2'b10) be_dec <= 4'b0100;
        else be_dec <= 4'b1000;
      end
      3'h2 : begin
        if(addr_i[1]) be_dec <= 4'b1100;
        else          be_dec <= 4'b0011;
      end
      3'h4: be_dec <= 4'b1111;
      default : be_dec <= 4'b1111;  // default to 32-bit access
    endcase 
  end
  `else
  // This is for a BIG ENDIAN CPU...lowest-addressed byte is 
  // the 8 most significant bits of the 32-bit WB bus.
  always @ (word_size_i or addr_i) begin
    case (word_size_i)
      3'h1 : begin
        if(addr_i[1:0] == 2'b00) be_dec <= 4'b1000;
        else if(addr_i[1:0] == 2'b01) be_dec <= 4'b0100;
        else if(addr_i[1:0] == 2'b10) be_dec <= 4'b0010;
        else be_dec <= 4'b0001;
      end
      3'h2 : begin
        if(addr_i[1] == 1'b1) be_dec <= 4'b0011;
        else                  be_dec <= 4'b1100;
      end
      3'h4: be_dec <= 4'b1111;
      default : be_dec <= 4'b1111;  // default to 32-bit access
    endcase
  end
  `endif

  // Byte- or word-swap data as necessary.  Use the non-latched be_dec signal,
  // since it and the swapped data will be latched at the same time.
  // Remember that since the data is shifted in LSB-first, shorter words
  // will be in the high-order bits. (combinatorial)
  always @ (be_dec or data_i) begin
    case (be_dec)
      4'b1111: swapped_data_i <= data_i;
      4'b0011: swapped_data_i <= {16'h0,data_i[31:16]};
      4'b1100: swapped_data_i <= data_i;
      4'b0001: swapped_data_i <= {24'h0, data_i[31:24]};
      4'b0010: swapped_data_i <= {16'h0, data_i[31:24], 8'h0};
      4'b0100: swapped_data_i <= {8'h0, data_i[31:24], 16'h0};
      4'b1000: swapped_data_i <= {data_i[31:24], 24'h0};
      default: swapped_data_i <= data_i;  // Shouldn't be possible
    endcase
  end

  // Latch input data on 'start' strobe, if ready.
  always @ (posedge tck_i or posedge rst_i) begin
    if(rst_i) begin
      sel_reg <= 4'h0;
      addr_reg <= 32'h0;
      data_in_reg <= 32'h0;
      wr_reg <= 1'b0;
    end
    else if(strobe_i && rdy_o) begin
      sel_reg <= be_dec;
      addr_reg <= addr_i;
      if(!rd_wrn_i) data_in_reg <= swapped_data_i;
      wr_reg <= ~rd_wrn_i;
    end 
  end

  // Create toggle-active strobe signal for clock sync.  This will start a transaction
  // on the WB once the toggle propagates to the FSM in the WB domain.
  always @ (posedge tck_i or posedge rst_i) begin
    if(rst_i) str_sync <= 1'b0;
    else if(strobe_i && rdy_o) str_sync <= ~str_sync;
  end 

  // Create rdy_o output.  Set on reset, clear on strobe (if set), set on input toggle
  always @ (posedge tck_i or posedge rst_i) begin
    if(rst_i) begin
      rdy_sync_tff1 <= 1'b0;
      rdy_sync_tff2 <= 1'b0;
      rdy_sync_tff2q <= 1'b0;
      rdy_o <= 1'b1; 
    end
    else begin  
      rdy_sync_tff1 <= rdy_sync;       // Synchronize the ready signal across clock domains
      rdy_sync_tff2 <= rdy_sync_tff1;
      rdy_sync_tff2q <= rdy_sync_tff2;  // used to detect toggles

      if(strobe_i && rdy_o) rdy_o <= 1'b0;
      else if(rdy_sync_tff2 != rdy_sync_tff2q) rdy_o <= 1'b1;
    end
  end 

  // Direct assignments, unsynchronized
  assign wb_dat_o = data_in_reg;
  assign wb_we_o = wr_reg;
  assign wb_adr_o = addr_reg;
  assign wb_sel_o = sel_reg;

  assign data_o = data_out_reg;
  assign err_o = err_reg;

  assign wb_cti_o = 3'h0;
  assign wb_bte_o = 2'h0;
  assign wb_cab_o = 1'b0;

  // Wishbone clock domain

  // synchronize the start strobe
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) begin
      str_sync_wbff1 <= 1'b0;
      str_sync_wbff2 <= 1'b0;
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
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) err_reg <= 1'b0;
    else if(err_en) err_reg <= wb_err_i; 
  end

  // Byte- or word-swap the WB->dbg data, as necessary (combinatorial)
  // We assume bits not required by SEL are don't care.  We reuse assignments
  // where possible to keep the MUX smaller.  (combinatorial)
  always @ (sel_reg or wb_dat_i) begin
    case (sel_reg)
      4'b1111: swapped_data_out <= wb_dat_i;
      4'b0011: swapped_data_out <= wb_dat_i;
      4'b1100: swapped_data_out <= {16'h0, wb_dat_i[31:16]};
      4'b0001: swapped_data_out <= wb_dat_i;
      4'b0010: swapped_data_out <= {24'h0, wb_dat_i[15:8]};
      4'b0100: swapped_data_out <= {16'h0, wb_dat_i[31:16]};
      4'b1000: swapped_data_out <= {24'h0, wb_dat_i[31:24]};
      default: swapped_data_out <= wb_dat_i;  // Shouldn't be possible
    endcase
  end

  // WB->dbg data register
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) data_out_reg <= 32'h0;
    else if(data_o_en) data_out_reg <= swapped_data_out;
  end

  // Create a toggle-active ready signal to send to the TCK domain
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) rdy_sync <= 1'b0;
    else if(rdy_sync_en) rdy_sync <= ~rdy_sync;
  end

  // Small state machine to create WB accesses
  // Not much more that an 'in_progress' bit, but easier
  // to read.  Deals with single-cycle and multi-cycle
  // accesses.

  // Sequential bit
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) wb_fsm_state <= `STATE_IDLE;
    else wb_fsm_state <= next_fsm_state; 
  end

  // Determination of next state (combinatorial)
  always @ (wb_fsm_state or start_toggle or wb_ack_i or wb_err_i) begin
    case (wb_fsm_state)
      `STATE_IDLE : begin
        if(start_toggle && !(wb_ack_i || wb_err_i)) next_fsm_state <= `STATE_TRANSFER;  // Don't go to next state for 1-cycle transfer
        else next_fsm_state <= `STATE_IDLE;
      end
      `STATE_TRANSFER : begin
        if(wb_ack_i || wb_err_i) next_fsm_state <= `STATE_IDLE;
        else next_fsm_state <= `STATE_TRANSFER;
      end
    endcase
  end

  // Outputs of state machine (combinatorial)
  always @ (wb_fsm_state or start_toggle or wb_ack_i or wb_err_i or wr_reg) begin
    rdy_sync_en <= 1'b0;
    err_en <= 1'b0;
    data_o_en <= 1'b0;
    wb_cyc_o <= 1'b0;
    wb_stb_o <= 1'b0;

    case (wb_fsm_state)
      `STATE_IDLE :  begin
        if(start_toggle) begin
          wb_cyc_o <= 1'b1;
          wb_stb_o <= 1'b1;
          if(wb_ack_i || wb_err_i) begin
            err_en <= 1'b1;
            rdy_sync_en <= 1'b1;
          end
          if (wb_ack_i && !wr_reg) begin
            data_o_en <= 1'b1;
          end
        end
      end
      `STATE_TRANSFER : begin
        wb_cyc_o <= 1'b1;
        wb_stb_o <= 1'b1;
        if(wb_ack_i) begin
          err_en <= 1'b1;
          data_o_en <= 1'b1;
          rdy_sync_en <= 1'b1;
        end
        else if (wb_err_i) begin
          err_en <= 1'b1;
          rdy_sync_en <= 1'b1;
        end
      end
    endcase
  end
endmodule
