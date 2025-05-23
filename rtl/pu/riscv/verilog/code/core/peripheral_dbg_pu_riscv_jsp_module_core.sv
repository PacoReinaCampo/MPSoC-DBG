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
//              AMBA4 AHB-Lite Bus Interface                                  //
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

`include "peripheral_dbg_pu_riscv_pkg.sv"

// Module interface
module peripheral_dbg_pu_riscv_jsp_module_core #(
  parameter DBG_JSP_DATAREG_LEN = 64
) (
  input rst_i,

  // JTAG signals
  input  tck_i,
  input  tdi_i,
  output module_tdo_o,

  // TAP states
  input capture_dr_i,
  input shift_dr_i,
  input update_dr_i,

  input  [DBG_JSP_DATAREG_LEN-1:0] data_register_i,  // the data register is at top level, shared between all modules
  input                            module_select_i,
  output                           top_inhibit_o,

  // JSP TILELINK interface
  output             biu_clk,
  output             biu_rst,
  output       [7:0] biu_di,               // data towards TILELINK
  input        [7:0] biu_do,               // data from TILELINK
  input        [3:0] biu_space_available,
  input        [3:0] biu_bytes_available,
  output logic       biu_rd_strobe,        // Indicates that the TILELINK should ACK last read operation + start another
  output logic       biu_wr_strobe         // Indicates TILELINK should latch input + begin a write operation
);

  // NOTE:  For the rest of this file, "input" and the "in" direction refer to bytes being transferred
  // from the PC, through the JTAG, and into the TILELINK FIFO.  The "output" direction refers to data being
  // transferred from the TILELINK FIFO, through the JTAG to the PC.

  // The read and write bit counts are separated to allow for JTAG chains with multiple devices.
  // The read bit count starts right away (after a single throwaway bit), but the write count
  // waits to receive a '1' start bit.

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  // FSM states
  localparam STATE_WR_IDLE = 2'b11;
  localparam STATE_WR_WAIT = 2'b10;
  localparam STATE_WR_COUNTS = 2'b01;
  localparam STATE_WR_XFER = 2'b00;

  localparam STATE_RD_IDLE = 2'b11;
  localparam STATE_RD_COUNTS = 2'b10;
  localparam STATE_RD_RDACK = 2'b01;
  localparam STATE_RD_XFER = 2'b00;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // Registers to hold state etc.
  logic [3:0] read_bit_count;  // How many bits have been shifted out
  logic [3:0] write_bit_count;  // How many bits have been shifted in
  logic [3:0] input_word_count;  // space (bytes) remaining in input FIFO (from JTAG)
  logic [3:0] output_word_count;  // bytes remaining in output FIFO (to JTAG)
  logic [3:0] user_word_count;  // bytes user intends to send from PC
  logic [7:0] data_out_shift_reg;  // parallel-load output shift register

  // Control signals for the various counters / registers / state machines
  logic       rd_bit_ct_en;  // enable bit counter
  logic       rd_bit_ct_rst;  // reset (zero) bit count register
  logic       wr_bit_ct_en;  // enable bit counter
  logic       wr_bit_ct_rst;  // reset (zero) bit count register   
  logic       in_word_ct_sel;  // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
  logic       out_word_ct_sel;  // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
  logic       in_word_ct_en;  // Enable input byte counter register
  logic       out_word_ct_en;  // Enable output byte count register
  logic       user_word_ct_en;  // Enable user byte count registere
  logic       user_word_ct_sel;  // selects data for user byte counter.  0 = user data, 1 = decremented byte count
  logic       out_reg_ld_en;  // Enable parallel load of data_out_shift_reg
  logic       out_reg_shift_en;  // Enable shift of data_out_shift_reg
  logic       out_reg_data_sel;  // 0 = TILELINK data, 1 = byte count data (also from TILELINK)

  // Status signals
  logic       in_word_count_zero;  // true when input byte counter is zero
  logic       out_word_count_zero;  // true when output byte counter is zero
  logic       user_word_count_zero;  // true when user byte counter is zero
  logic       rd_bit_count_max;  // true when bit counter is equal to current word size
  logic       wr_bit_count_max;  // true when bit counter is equal to current word size

  // Intermediate signals
  logic [3:0] data_to_in_word_counter;  // output of the mux in front of the input byte counter reg
  logic [3:0] data_to_out_word_counter;  // output of the mux in front of the output byte counter reg
  logic [3:0] data_to_user_word_counter;  // output of mux in front of user word counter
  logic [3:0] count_data_in;  // from data_register_i
  logic [7:0] data_to_tl;  // from data_register_i
  logic [7:0] data_from_tl;  // to data_out_shift_register
  logic [7:0] count_data_from_tl;  // combined space avail / bytes avail
  logic [7:0] out_reg_data;  // parallel input to the output shift register

  // Statemachine
  logic [1:0] wr_module_state, wr_module_next_state;
  logic [1:0] rd_module_state, rd_module_next_state;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // Combinatorial assignments
  assign count_data_from_tl = {biu_bytes_available, biu_space_available};
  assign count_data_in       = {tdi_i, data_register_i[DBG_JSP_DATAREG_LEN-1-:3]};  // Second nibble of user data
  assign data_to_tl         = {tdi_i, data_register_i[DBG_JSP_DATAREG_LEN-1-:7]};
  assign top_inhibit_o       = 1'b0;

  // Input bit counter
  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      write_bit_count <= 'h0;
    end else if (wr_bit_ct_rst) begin
      write_bit_count <= 'h0;
    end else if (wr_bit_ct_en) begin
      write_bit_count <= write_bit_count + 'h1;
    end
  end

  assign wr_bit_count_max = write_bit_count == 4'h7;

  // Output bit counter
  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      read_bit_count <= 'h0;
    end else if (rd_bit_ct_rst) begin
      read_bit_count <= 'h0;
    end else if (rd_bit_ct_en) begin
      read_bit_count <= read_bit_count + 'h1;
    end
  end

  assign rd_bit_count_max        = read_bit_count == 4'h7;

  // Input word counter
  assign data_to_in_word_counter = in_word_ct_sel ? input_word_count - 'h1 : biu_space_available;

  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      input_word_count <= 'h0;
    end else if (in_word_ct_en) begin
      input_word_count <= data_to_in_word_counter;
    end
  end

  assign in_word_count_zero       = (input_word_count == 4'h0);

  // Output word counter
  assign data_to_out_word_counter = out_word_ct_sel ? output_word_count - 'h1 : biu_bytes_available;

  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      output_word_count <= 'h0;
    end else if (out_word_ct_en) begin
      output_word_count <= data_to_out_word_counter;
    end
  end

  assign out_word_count_zero       = ~|output_word_count;

  // User word counter
  assign data_to_user_word_counter = user_word_ct_sel ? user_word_count - 'h1 : count_data_in;

  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      user_word_count <= 'h0;
    end else if (user_word_ct_en) begin
      user_word_count <= data_to_user_word_counter;
    end
  end

  assign user_word_count_zero = ~|user_word_count;

  // Output register and TDO output MUX
  assign out_reg_data         = (out_reg_data_sel) ? count_data_from_tl : data_from_tl;

  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      data_out_shift_reg <= 'h0;
    end else if (out_reg_ld_en) begin
      data_out_shift_reg <= out_reg_data;
    end else if (out_reg_shift_en) begin
      data_out_shift_reg <= {1'b0, data_out_shift_reg[$bits(data_out_shift_reg)-1:1]};
    end
  end

  assign module_tdo_o  = data_out_shift_reg[0];

  // Bus Interface Unit (to JTAG / WB UART)
  // It is assumed that the TILELINK has internal registers, and will
  // latch write data (and ack read data) on rising clock edge 
  // when strobe is asserted
  assign biu_clk       = tck_i;
  assign biu_rst       = rst_i;
  assign biu_di        = data_to_tl;
  assign data_from_tl = biu_do;

  //   peripheral_dbg_jsp_tl jsp_tl_i (
  //    // Debug interface signals
  //    .tck_i           (tck_i),
  //    .rst_i           (rst_i),
  //    .data_i          (data_to_tl),
  //    .data_o          (data_from_tl),
  //    .bytes_available_o (biu_bytes_available),
  //    .bytes_free_o    (biu_space_available),
  //    .rd_strobe_i     (biu_rd_strobe),
  //    .wr_strobe_i     (biu_wr_strobe),

  //    // Wishbone slave signals
  //    .wb_clk_i        (wb_clk_i),
  //    .wb_rst_i        (wb_rst_i),
  //    .wb_adr_i        (wb_adr_i),
  //    .wb_dat_o        (wb_dat_o),
  //    .wb_dat_i        (wb_dat_i),
  //    .wb_cyc_i        (wb_cyc_i),
  //    .wb_stb_i        (wb_stb_i),
  //    .wb_sel_i        (wb_sel_i),
  //    .wb_we_i         (wb_we_i),
  //    .wb_ack_o        (wb_ack_o),
  //    .wb_err_o        (wb_err_o),
  //    .wb_cti_i        (wb_cti_i),
  //    .wb_bte_i        (wb_bte_i),
  //    .int_o           (int_o)
  //  );

  // Input Control FSM

  // sequential part of the FSM
  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      wr_module_state <= STATE_WR_IDLE;
    end else begin
      wr_module_state <= wr_module_next_state;
    end
  end

  // Determination of next state; purely combinatorial
  always @(*) begin
    case (wr_module_state)
      STATE_WR_IDLE: begin
        if (module_select_i && capture_dr_i) begin
          wr_module_next_state = STATE_WR_COUNTS;
        end else begin
          wr_module_next_state = STATE_WR_IDLE;
        end
      end
      STATE_WR_WAIT: begin
        if (update_dr_i) begin
          wr_module_next_state = STATE_WR_IDLE;
        end else if (module_select_i && tdi_i) begin
          wr_module_next_state = STATE_WR_COUNTS;  // got start bit
        end else begin
          wr_module_next_state = STATE_WR_WAIT;
        end
      end
      STATE_WR_COUNTS: begin
        if (update_dr_i) begin
          wr_module_next_state = STATE_WR_IDLE;
        end else if (wr_bit_count_max) begin
          wr_module_next_state = STATE_WR_XFER;
        end else begin
          wr_module_next_state = STATE_WR_COUNTS;
        end
      end
      STATE_WR_XFER: begin
        if (update_dr_i) begin
          wr_module_next_state = STATE_WR_IDLE;
        end else begin
          wr_module_next_state = STATE_WR_XFER;
        end
      end
      default: begin
        wr_module_next_state = STATE_WR_IDLE;  // shouldn't actually happen...
      end
    endcase
  end

  // Outputs of state machine, pure combinatorial
  always @(*) begin
    // Default everything to 0, keeps the case statement simple
    wr_bit_ct_en     = 1'b0;  // enable bit counter
    wr_bit_ct_rst    = 1'b0;  // reset (zero) bit count register
    in_word_ct_sel   = 1'b0;  // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    user_word_ct_sel = 1'b0;  // selects data for user byte counter, 0 = user data, 1 = decremented count
    in_word_ct_en    = 1'b0;  // Enable input byte counter register
    user_word_ct_en  = 1'b0;  // enable user byte count register
    biu_wr_strobe    = 1'b0;  // Indicates TILELINK should latch input + begin a write operation

    case (wr_module_state)
      STATE_WR_IDLE: begin
        in_word_ct_sel = 1'b0;

        // Going to transfer; enable count registers and output register
        if (wr_module_next_state != STATE_WR_IDLE) begin
          wr_bit_ct_rst = 1'b1;
          in_word_ct_en = 1'b1;
        end
      end

      // This state is only used when support for multi-device JTAG chains is enabled.
      STATE_WR_WAIT: wr_bit_ct_en = 1'b0;  // Don't do anything, just wait for the start bit.

      STATE_WR_COUNTS:
      if (shift_dr_i) begin  // Don't do anything in PAUSE or EXIT states...
        wr_bit_ct_en     = 1'b1;
        user_word_ct_sel = 1'b0;

        if (wr_bit_count_max) begin
          wr_bit_ct_rst   = 1'b1;
          user_word_ct_en = 1'b1;
        end
      end

      STATE_WR_XFER: begin
        if (shift_dr_i) begin  // Don't do anything in PAUSE or EXIT states
          wr_bit_ct_en     = 1'b1;
          in_word_ct_sel   = 1'b1;
          user_word_ct_sel = 1'b1;

          if (wr_bit_count_max) begin  // Start tl transactions, if word counts allow
            wr_bit_ct_rst = 1'b1;

            if (!(in_word_count_zero || user_word_count_zero)) begin
              biu_wr_strobe   = 1'b1;
              in_word_ct_en   = 1'b1;
              user_word_ct_en = 1'b1;
            end
          end
        end
      end
      default: begin
      end
    endcase
  end

  // Output Control FSM

  // We do not send the equivalent of a 'start bit' (like the one the input FSM
  // waits for when support for multi-device JTAG chains is enabled).  Since the
  // input and output are going to be offset anyway, why bother...

  // sequential part of the FSM
  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      rd_module_state = STATE_RD_IDLE;
    end else begin
      rd_module_state = rd_module_next_state;
    end
  end

  // Determination of next state; purely combinatorial
  always @(*) begin
    case (rd_module_state)
      STATE_RD_IDLE: begin
        if (module_select_i && capture_dr_i) begin
          rd_module_next_state = STATE_RD_COUNTS;
        end else begin
          rd_module_next_state = STATE_RD_IDLE;
        end
      end
      STATE_RD_COUNTS: begin
        if (update_dr_i) begin
          rd_module_next_state = STATE_RD_IDLE;
        end else if (rd_bit_count_max) begin
          rd_module_next_state = STATE_RD_RDACK;
        end else begin
          rd_module_next_state = STATE_RD_COUNTS;
        end
      end
      STATE_RD_RDACK: begin
        if (update_dr_i) begin
          rd_module_next_state = STATE_RD_IDLE;
        end else begin
          rd_module_next_state = STATE_RD_XFER;
        end
      end
      STATE_RD_XFER: begin
        if (update_dr_i) begin
          rd_module_next_state = STATE_RD_IDLE;
        end else if (rd_bit_count_max) begin
          rd_module_next_state = STATE_RD_RDACK;
        end else begin
          rd_module_next_state = STATE_RD_XFER;
        end
      end
      default: begin
        rd_module_next_state = STATE_RD_IDLE;  // shouldn't actually happen...
      end
    endcase
  end

  // Outputs of state machine, pure combinatorial
  always @(*) begin
    // Default everything to 0, keeps the case statement simple
    rd_bit_ct_en     = 1'b0;  // enable bit counter
    rd_bit_ct_rst    = 1'b0;  // reset (zero) bit count register
    out_word_ct_sel  = 1'b0;  // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    out_word_ct_en   = 1'b0;  // Enable output byte count register
    out_reg_ld_en    = 1'b0;  // Enable parallel load of data_out_shift_reg
    out_reg_shift_en = 1'b0;  // Enable shift of data_out_shift_reg
    out_reg_data_sel = 1'b0;  // 0 = TILELINK data, 1 = byte count data (also from TILELINK)
    biu_rd_strobe    = 1'b0;  // Indicates that the bus unit should ACK the last read operation + start another

    case (rd_module_state)
      STATE_RD_IDLE: begin
        out_reg_data_sel = 1'b1;
        out_word_ct_sel  = 1'b0;

        // Going to transfer; enable count registers and output register
        if (rd_module_next_state != STATE_RD_IDLE) begin
          out_reg_ld_en  = 1'b1;
          rd_bit_ct_rst  = 1'b1;
          out_word_ct_en = 1'b1;
        end
      end

      STATE_RD_COUNTS: begin
        if (shift_dr_i) begin  // Don't do anything in PAUSE or EXIT states...
          rd_bit_ct_en     = 1'b1;
          out_reg_shift_en = 1'b1;

          if (rd_bit_count_max) begin
            rd_bit_ct_rst = 1'b1;

            // Latch the next output word, but don't ack until STATE_RD_RDACK
            if (!out_word_count_zero) begin
              out_reg_ld_en    = 1'b1;
              out_reg_shift_en = 1'b0;
            end
          end
        end
      end
      STATE_RD_RDACK: begin
        if (shift_dr_i) begin  // Don't do anything in PAUSE or EXIT states
          rd_bit_ct_en     = 1'b1;
          out_reg_shift_en = 1'b1;
          out_reg_data_sel = 1'b0;

          // Never have to worry about bit_count_max here.
          if (!out_word_count_zero) begin
            biu_rd_strobe = 1'b1;
          end
        end
      end
      STATE_RD_XFER: begin
        if (shift_dr_i) begin  // Don't do anything in PAUSE or EXIT states
          rd_bit_ct_en     = 1'b1;
          out_word_ct_sel  = 1'b1;
          out_reg_shift_en = 1'b1;
          out_reg_data_sel = 1'b0;

          if (rd_bit_count_max) begin  // Start tl transaction, if word count allows
            rd_bit_ct_rst = 1'b1;

            // Don't ack the read byte here, we do it in STATE_RDACK
            if (!out_word_count_zero) begin
              out_reg_ld_en    = 1'b1;
              out_reg_shift_en = 1'b0;
              out_word_ct_en   = 1'b1;
            end
          end
        end
      end
      default: begin
      end
    endcase
  end
endmodule
