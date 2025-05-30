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

`include "peripheral_dbg_pu_or1k_defines.sv"
`include "peripheral_dbg_pu_or1k_defines_apb4.sv"

// Top module
module peripheral_dbg_pu_or1k_module_apb4 #(
  parameter ADBG_USE_HISPEED = "ENABLED"
) (
  // JTAG signals
  input      tck_i,
  output reg module_tdo_o,
  input      tdi_i,         // This is only used by the CRC module - data_register_i[MSB] is delayed a cycle

  // TAP states
  input capture_dr_i,
  input shift_dr_i,
  input update_dr_i,

  input      [52:0] data_register_i,
  input             module_select_i,
  output reg        top_inhibit_o,
  input             rst_i,

  // WISHBONE master interface
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

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  `define STATE_idle 4'h0
  `define STATE_Rbegin 4'h1
  `define STATE_Rready 4'h2
  `define STATE_Rstatus 4'h3
  `define STATE_Rburst 4'h4
  `define STATE_Wready 4'h5
  `define STATE_Wwait 4'h6
  `define STATE_Wburst 4'h7
  `define STATE_Wstatus 4'h8
  `define STATE_Rcrc 4'h9
  `define STATE_Wcrc 4'ha
  `define STATE_Wmatch 4'hb

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // Registers to hold state etc.
  reg  [                      31:0] address_counter;  // Holds address for next Wishbone access
  reg  [                       5:0] bit_count;  // How many bits have been shifted in/out
  reg  [                      15:0] word_count;  // bytes remaining in current burst command
  reg  [                       3:0] operation;  // holds the current command (rd/wr, word size)
  reg  [                      32:0] data_out_shift_reg;  // 32 bits to accomodate the internal_reg_error
  reg  [                      32:0] internal_reg_error;  // WB error module internal register.  32 bit address + error bit (LSB)

  reg  [`DBG_WB_REGSELECT_SIZE-1:0] internal_register_select;  // Holds index of currently selected register

  // Control signals for the various counters / registers / state machines
  reg                               addr_sel;  // Selects data for address_counter. 0 = data_register_i, 1 = incremented address count
  reg                               addr_ct_en;  // Enable signal for address counter register
  reg                               op_reg_en;  // Enable signal for 'operation' register
  reg                               bit_ct_en;  // enable bit counter
  reg                               bit_ct_rst;  // reset (zero) bit count register
  reg                               word_ct_sel;  // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
  reg                               word_ct_en;  // Enable byte counter register
  reg                               out_reg_ld_en;  // Enable parallel load of data_out_shift_reg
  reg                               out_reg_shift_en;  // Enable shift of data_out_shift_reg
  reg                               out_reg_data_sel;  // 0 = TILELINK data, 1 = internal register data
  reg  [                       1:0] tdo_output_sel;  // Selects signal to send to TDO.  0 = ready bit, 1 = output register, 2 = CRC match, 3 = CRC shift reg.
  reg                               wb_strobe;  // Indicates that the bus unit should latch data and start a transaction
  reg                               crc_clr;  // resets CRC module
  reg                               crc_en;  // does 1-bit iteration in CRC module
  reg                               crc_in_sel;  // selects incoming write data (=0) or outgoing read data (=1)as input to CRC module
  reg                               crc_shift_en;  // CRC reg is also it's own output shift register; this enables a shift
  reg                               regsel_ld_en;  // Reg. select register load enable
  reg                               intreg_ld_en;  // load enable for internal registers
  reg                               error_reg_en;  // Tells the error register to check for and latch a bus error
  reg                               wb_clr_err;  // Allows FSM to reset TILELINK, to clear the wb_err bit which may have been set on the last transaction of the last burst.

  // Status signals
  wire                              word_count_zero;  // true when byte counter is zero
  wire                              bit_count_max;  // true when bit counter is equal to current word size
  wire                              module_cmd;  // inverse of MSB of data_register_i. 1 means current cmd not for top level (but is for us)
  wire                              wb_ready;  // indicates that the TILELINK has finished the last command
  wire                              wb_err;  // indicates wishbone error during TILELINK transaction
  wire                              burst_instruction;  // True when the input_data_i reg has a valid burst instruction for this module
  wire                              intreg_instruction;  // True when the input_data_i reg has a valid internal register instruction
  wire                              intreg_write;  // True when the input_data_i reg has an internal register write op
  reg                               rd_op;  // True when operation in the opcode reg is a read, false when a write
  wire                              crc_match;  // indicates whether data_register_i matches computed CRC
  wire                              bit_count_32;  // true when bit count register == 32, for CRC after burst writes

  // Intermediate signals
  reg  [                       5:0] word_size_bits;  // 8,16, or 32.  Decoded from 'operation'
  reg  [                       2:0] word_size_bytes;  // 1,2, or 4
  wire [                      32:0] incremented_address;  // value of address counter plus 'word_size'
  wire [                      31:0] data_to_addr_counter;  // output of the mux in front of the address counter inputs
  wire [                      15:0] data_to_word_counter;  // output of the mux in front of the byte counter input
  wire [                      15:0] decremented_word_count;
  wire [                      31:0] address_data_in;  // from data_register_i
  wire [                      15:0] count_data_in;  // from data_register_i
  wire [                       3:0] operation_in;  // from data_register_i
  wire [                      31:0] data_to_tl;  // from data_register_i
  wire [                      31:0] data_from_tl;  // to data_out_shift_register
  wire [                      31:0] crc_data_out;  // output of CRC module, to output shift register
  wire                              crc_data_in;  // input to CRC module, either data_register_i[52] or data_out_shift_reg[0]
  wire                              crc_serial_out;
  wire [                      32:0] out_reg_data;  // parallel input to the output shift register
  reg  [                      32:0] data_from_internal_reg;  // data from internal reg. MUX to output shift register
  wire                              wb_rst;  // logical OR of rst_i and wb_clr_err

  wire [`DBG_WB_REGSELECT_SIZE-1:0] reg_select_data;  // from data_register_i, input to internal register select register

  reg  [                       3:0] module_state;  // FSM state
  reg  [                       3:0] module_next_state;  // combinatorial signal, not actually a register

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // Combinatorial assignments
  assign module_cmd      = ~(data_register_i[52]);
  assign operation_in    = data_register_i[51:48];
  assign address_data_in = data_register_i[47:16];
  assign count_data_in   = data_register_i[15:0];
  assign reg_select_data = data_register_i[47:(47-(`DBG_WB_REGSELECT_SIZE-1))];

  generate
    if (ADBG_USE_HISPEED != "NONE") begin
      assign data_to_tl = {tdi_i, data_register_i[52:22]};
    end else begin
      assign data_to_tl = data_register_i[52:21];
    end
  endgenerate

  // Operation decoder

  // These are only used before the operation is latched, so decode them from operation_in
  assign burst_instruction  = (~operation_in[3]) & (operation_in[0] | operation_in[1]);
  assign intreg_instruction = ((operation_in == `DBG_WB_CMD_IREG_WR) | (operation_in == `DBG_WB_CMD_IREG_SEL));
  assign intreg_write       = (operation_in == `DBG_WB_CMD_IREG_WR);

  // This is decoded from the registered operation
  always @(operation) begin
    case (operation)
      `DBG_WB_CMD_BWRITE8: begin
        word_size_bits  <= 5'd7;  // Bits is actually bits-1, to make the FSM easier
        word_size_bytes <= 3'd1;
        rd_op           <= 1'b0;
      end
      `DBG_WB_CMD_BWRITE16: begin
        word_size_bits  <= 5'd15;  // Bits is actually bits-1, to make the FSM easier
        word_size_bytes <= 3'd2;
        rd_op           <= 1'b0;
      end
      `DBG_WB_CMD_BWRITE32: begin
        word_size_bits  <= 5'd31;  // Bits is actually bits-1, to make the FSM easier
        word_size_bytes <= 3'd4;
        rd_op           <= 1'b0;
      end
      `DBG_WB_CMD_BREAD8: begin
        word_size_bits  <= 5'd7;  // Bits is actually bits-1, to make the FSM easier
        word_size_bytes <= 3'd1;
        rd_op           <= 1'b1;
      end
      `DBG_WB_CMD_BREAD16: begin
        word_size_bits  <= 5'd15;  // Bits is actually bits-1, to make the FSM easier
        word_size_bytes <= 3'd2;
        rd_op           <= 1'b1;
      end
      `DBG_WB_CMD_BREAD32: begin
        word_size_bits  <= 5'd31;  // Bits is actually bits-1, to make the FSM easier
        word_size_bytes <= 3'd4;
        rd_op           <= 1'b1;
      end
      default: begin
        word_size_bits  <= 5'hXX;
        word_size_bytes <= 3'hX;
        rd_op           <= 1'bX;
      end
    endcase
  end

  // Module-internal register select register (no, that's not redundant.)
  // Also internal register output MUX
  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      internal_register_select = 1'h0;
    end else if (regsel_ld_en) begin
      internal_register_select = reg_select_data;
    end
  end

  // This is completely unnecessary here, since the WB module has only 1 internal
  // register.  However, to make the module expandable, it is included anyway.
  always @(internal_register_select or internal_reg_error) begin
    case (internal_register_select)
      `DBG_WB_INTREG_ERROR: begin
        data_from_internal_reg = internal_reg_error;
      end
      default: begin
        data_from_internal_reg = internal_reg_error;
      end
    endcase
  end

  // Module-internal registers
  // These have generic read/write/select code, but
  // individual registers may have special behavior, defined here.

  // This is the bus error register, which traps WB errors
  // We latch every new TILELINK address in the upper 32 bits, so we always have the address for the transaction which
  // generated the error (the address counter might increment, esp. for writes)
  // We stop latching addresses when the error bit (bit 0) is set. Keep the error bit set until it is 
  // manually cleared by a module internal register write.
  // Note we use reg_select_data straight from data_register_i, rather than the latched version - 
  // otherwise, we would write the previously selected register.

  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      internal_reg_error = 33'h0;
    end else if (intreg_ld_en && (reg_select_data == `DBG_WB_INTREG_ERROR)) begin  // do load from data input register
      if (data_register_i[46]) begin
        internal_reg_error[0] = 1'b0;  // if write data is 1, reset the error bit
      end
    end else if (error_reg_en && !internal_reg_error[0]) begin
      if (ADBG_USE_HISPEED != "NONE") begin
        if (wb_err || (!wb_ready)) begin
          internal_reg_error[0] = 1'b1;
        end else if (wb_err) begin
          internal_reg_error[0] = 1'b1;
        end else if (wb_strobe) begin
          internal_reg_error[32:1] = address_counter;
        end
      end
    end else if (wb_strobe && !internal_reg_error[0]) begin
      internal_reg_error[32:1] = address_counter;  // When no error, latch this whether error_reg_en or not
    end
  end

  // Address counter
  assign data_to_addr_counter = (addr_sel) ? incremented_address[31:0] : address_data_in;
  assign incremented_address  = address_counter + word_size_bytes;

  // Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  // negedge, per the JTAG spec. But that makes things difficult when incrementing.
  always @(posedge tck_i or posedge rst_i) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if (rst_i) begin
      address_counter <= 32'h0;
    end else if (addr_ct_en) begin
      address_counter <= data_to_addr_counter;
    end
  end

  // Opcode latch
  always @(posedge tck_i or posedge rst_i) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if (rst_i) begin
      operation <= 4'h0;
    end else if (op_reg_en) begin
      operation <= operation_in;
    end
  end

  // Bit counter
  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      bit_count <= 6'h0;
    end else if (bit_ct_rst) begin
      bit_count <= 6'h0;
    end else if (bit_ct_en) begin
      bit_count <= bit_count + 6'h1;
    end
  end

  assign bit_count_max          = (bit_count == word_size_bits) ? 1'b1 : 1'b0;
  assign bit_count_32           = (bit_count == 6'h20) ? 1'b1 : 1'b0;

  // Word counter
  assign data_to_word_counter   = (word_ct_sel) ? decremented_word_count : count_data_in;
  assign decremented_word_count = word_count - 16'h1;

  // Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  // negedge, per the JTAG spec. But that makes things difficult when incrementing.
  always @(posedge tck_i or posedge rst_i) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if (rst_i) begin
      word_count <= 16'h0;
    end else if (word_ct_en) begin
      word_count <= data_to_word_counter;
    end
  end

  assign word_count_zero = (word_count == 16'h0);

  // Output register and TDO output MUX
  assign out_reg_data    = (out_reg_data_sel) ? data_from_internal_reg : {1'b0, data_from_tl};

  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      data_out_shift_reg <= 33'h0;
    end else if (out_reg_ld_en) begin
      data_out_shift_reg <= out_reg_data;
    end else if (out_reg_shift_en) begin
      data_out_shift_reg <= {1'b0, data_out_shift_reg[32:1]};
    end
  end

  always @(tdo_output_sel or data_out_shift_reg[0] or wb_ready or crc_match or crc_serial_out) begin
    if (tdo_output_sel == 2'h0) begin
      module_tdo_o <= wb_ready;
    end else if (tdo_output_sel == 2'h1) begin
      module_tdo_o <= data_out_shift_reg[0];
    end else if (tdo_output_sel == 2'h2) begin
      module_tdo_o <= crc_match;
    end else begin
      module_tdo_o <= crc_serial_out;
    end
  end

  // Bus Interface Unit
  // It is assumed that the TILELINK has internal registers, and will
  // latch address, operation, and write data on rising clock edge 
  // when strobe is asserted

  assign wb_rst = rst_i | wb_clr_err;

  peripheral_dbg_pu_or1k_apb4_tl apb4_apb4_i (
    // Debug interface signals
    .tck_i      (tck_i),
    .rst_i      (wb_rst),
    .data_i     (data_to_tl),
    .data_o     (data_from_tl),
    .addr_i     (address_counter),
    .strobe_i   (wb_strobe),
    .rd_wrn_i   (rd_op),            // If 0, then write op
    .rdy_o      (wb_ready),
    .err_o      (wb_err),
    .word_size_i(word_size_bytes),

    // Wishbone signals
    .wb_clk_i(wb_clk_i),
    .wb_adr_o(wb_adr_o),
    .wb_dat_o(wb_dat_o),
    .wb_dat_i(wb_dat_i),
    .wb_cyc_o(wb_cyc_o),
    .wb_stb_o(wb_stb_o),
    .wb_sel_o(wb_sel_o),
    .wb_we_o (wb_we_o),
    .wb_ack_i(wb_ack_i),
    .wb_cab_o(wb_cab_o),
    .wb_err_i(wb_err_i),
    .wb_cti_o(wb_cti_o),
    .wb_bte_o(wb_bte_o)
  );

  // CRC module
  assign crc_data_in = (crc_in_sel) ? tdi_i : data_out_shift_reg[0];  // MUX, write or read data

  peripheral_dbg_pu_or1k_crc32 wb_crc_i (
    .clk       (tck_i),
    .data      (crc_data_in),
    .enable    (crc_en),
    .shift     (crc_shift_en),
    .clr       (crc_clr),
    .rst       (rst_i),
    .crc_out   (crc_data_out),
    .serial_out(crc_serial_out)
  );

  assign crc_match = (data_register_i[52:21] == crc_data_out) ? 1'b1 : 1'b0;

  // Control FSM

  // Definition of machine state values.
  // Don't worry too much about the state encoding, the synthesis tool
  // will probably re-encode it anyway.

  // sequential part of the FSM
  always @(posedge tck_i or posedge rst_i) begin
    if (rst_i) begin
      module_state <= `STATE_idle;
    end else begin
      module_state <= module_next_state;
    end
  end

  // Determination of next state; purely combinatorial
  always @(module_state or module_select_i or module_cmd or update_dr_i or capture_dr_i or operation_in[2] or word_count_zero or bit_count_max or data_register_i[52] or bit_count_32 or wb_ready or burst_instruction) begin
    case (module_state)
      `STATE_idle: begin
        if (module_cmd && module_select_i && update_dr_i && burst_instruction && operation_in[2]) begin
          module_next_state <= `STATE_Rbegin;
        end else if (module_cmd && module_select_i && update_dr_i && burst_instruction) begin
          module_next_state <= `STATE_Wready;
        end else begin
          module_next_state <= `STATE_idle;
        end
      end
      `STATE_Rbegin: begin
        if (word_count_zero) begin
          module_next_state <= `STATE_idle;  // set up a burst of size 0, illegal.
        end else begin
          module_next_state <= `STATE_Rready;
        end
      end
      `STATE_Rready: begin
        if (module_select_i && capture_dr_i) begin
          module_next_state <= `STATE_Rstatus;
        end else begin
          module_next_state <= `STATE_Rready;
        end
      end
      `STATE_Rstatus: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;
        end else if (wb_ready) begin
          module_next_state <= `STATE_Rburst;
        end else begin
          module_next_state <= `STATE_Rstatus;
        end
      end
      `STATE_Rburst: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;
        end else if (bit_count_max && word_count_zero) begin
          module_next_state <= `STATE_Rcrc;
        end else if (bit_count_max && ADBG_USE_HISPEED == "NONE") begin
          module_next_state <= `STATE_Rstatus;
        end else begin
          module_next_state <= `STATE_Rburst;
        end
      end
      `STATE_Rcrc: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;
          // This doubles as the 'recovery' state, so stay here until update_dr_i.
        end else begin
          module_next_state <= `STATE_Rcrc;
        end
      end
      `STATE_Wready: begin
        if (word_count_zero) begin
          module_next_state <= `STATE_idle;
        end else if (module_select_i && capture_dr_i) begin
          module_next_state <= `STATE_Wwait;
        end else begin
          module_next_state <= `STATE_Wready;
        end
      end
      `STATE_Wwait: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;  // client terminated early
        end else if (module_select_i && data_register_i[52]) begin
          module_next_state <= `STATE_Wburst;  // Got a start bit
        end else begin
          module_next_state <= `STATE_Wwait;
        end
      end
      `STATE_Wburst: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;  // client terminated early
        end else if (bit_count_max) begin
          if (ADBG_USE_HISPEED != "NONE") begin
            if (word_count_zero) begin
              module_next_state <= `STATE_Wcrc;
            end else begin
              module_next_state <= `STATE_Wburst;
            end
          end else begin
            module_next_state <= `STATE_Wstatus;
          end
        end else begin
          module_next_state <= `STATE_Wburst;
        end
      end
      `STATE_Wstatus: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;  // client terminated early    
        end else if (word_count_zero) begin
          module_next_state <= `STATE_Wcrc;
          // can't wait until bus ready if multiple devices in chain...
          // Would have to read postfix_bits, then send another start bit and push it through
          // prefix_bits...potentially very inefficient.
        end else begin
          module_next_state <= `STATE_Wburst;
        end
      end
      `STATE_Wcrc: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;  // client terminated early
        end else if (bit_count_32) begin
          module_next_state <= `STATE_Wmatch;
        end else begin
          module_next_state <= `STATE_Wcrc;
        end
      end
      `STATE_Wmatch: begin
        if (update_dr_i) begin
          module_next_state <= `STATE_idle;
          // This doubles as our recovery state, stay here until update_dr_i
        end else begin
          module_next_state <= `STATE_Wmatch;
        end
      end
      default: begin
        module_next_state <= `STATE_idle;  // shouldn't actually happen...
      end
    endcase
  end

  // Outputs of state machine, pure combinatorial
  always @ (module_state or module_next_state or module_select_i or update_dr_i or capture_dr_i or shift_dr_i or operation_in[2]
            or word_count_zero or bit_count_max or data_register_i[52] or wb_ready or intreg_instruction or module_cmd 
            or intreg_write or decremented_word_count) begin
    // Default everything to 0, keeps the case statement simple
    addr_sel         <= 1'b1;  // Selects data for address_counter. 0 = data_register_i, 1 = incremented address count
    addr_ct_en       <= 1'b0;  // Enable signal for address counter register
    op_reg_en        <= 1'b0;  // Enable signal for 'operation' register
    bit_ct_en        <= 1'b0;  // enable bit counter
    bit_ct_rst       <= 1'b0;  // reset (zero) bit count register
    word_ct_sel      <= 1'b1;  // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    word_ct_en       <= 1'b0;  // Enable byte counter register
    out_reg_ld_en    <= 1'b0;  // Enable parallel load of data_out_shift_reg
    out_reg_shift_en <= 1'b0;  // Enable shift of data_out_shift_reg
    tdo_output_sel   <= 2'b1;  // 1 = data reg, 0 = wb_ready, 2 = crc_match, 3 = CRC data
    wb_strobe       <= 1'b0;
    crc_clr          <= 1'b0;
    crc_en           <= 1'b0;  // add the input bit to the CRC calculation
    crc_in_sel       <= 1'b0;  // 0 = tdo, 1 = tdi
    crc_shift_en     <= 1'b0;
    out_reg_data_sel <= 1'b1;  // 0 = TILELINK data, 1 = internal register data
    regsel_ld_en     <= 1'b0;
    intreg_ld_en     <= 1'b0;
    error_reg_en     <= 1'b0;
    wb_clr_err      <= 1'b0;  // Set this to reset the TILELINK, clearing the wb_err bit
    top_inhibit_o    <= 1'b0;  // Don't disable the top-level module in the default case
    case (module_state)
      `STATE_idle: begin
        addr_sel    <= 1'b0;
        word_ct_sel <= 1'b0;
        // Operations for internal registers - stay in idle state
        if (module_select_i & shift_dr_i) begin
          out_reg_shift_en <= 1'b1;  // For module regs
        end
        if (module_select_i & capture_dr_i) begin
          out_reg_data_sel <= 1'b1;  // select internal register data
          out_reg_ld_en    <= 1'b1;  // For module regs
        end
        if (module_select_i & module_cmd & update_dr_i) begin
          if (intreg_instruction) begin
            regsel_ld_en <= 1'b1;  // For module regs
          end
          if (intreg_write) begin
            intreg_ld_en <= 1'b1;  // For module regs
          end
        end
        // Burst operations
        if (module_next_state != `STATE_idle) begin  // Do the same to receive read or write opcode
          addr_ct_en <= 1'b1;
          op_reg_en  <= 1'b1;
          bit_ct_rst <= 1'b1;
          word_ct_en <= 1'b1;
          crc_clr    <= 1'b1;
        end
      end
      `STATE_Rbegin: begin
        if (!word_count_zero) begin  // Start a tl read transaction
          wb_strobe <= 1'b1;
          addr_sel   <= 1'b1;
          addr_ct_en <= 1'b1;
        end
      end
      `STATE_Rready: ;  // Just a wait state
      `STATE_Rstatus: begin
        tdo_output_sel <= 2'h0;
        top_inhibit_o  <= 1'b1;  // in case of early termination
        if (module_next_state == `STATE_Rburst) begin
          error_reg_en     <= 1'b1;  // Check the wb_error bit
          out_reg_data_sel <= 1'b0;  // select TILELINK data
          out_reg_ld_en    <= 1'b1;
          bit_ct_rst       <= 1'b1;
          word_ct_sel      <= 1'b1;
          word_ct_en       <= 1'b1;
          if (!(decremented_word_count == 0) && !word_count_zero) begin  // Start a tl read transaction
            wb_strobe <= 1'b1;
            addr_sel   <= 1'b1;
            addr_ct_en <= 1'b1;
          end
        end
      end
      `STATE_Rburst: begin
        tdo_output_sel   <= 2'h1;
        out_reg_shift_en <= 1'b1;
        bit_ct_en        <= 1'b1;
        crc_en           <= 1'b1;
        crc_in_sel       <= 1'b0;  // read data in output shift register LSB (tdo)
        top_inhibit_o    <= 1'b1;  // in case of early termination
        if (ADBG_USE_HISPEED != "NONE" && bit_count_max) begin
          error_reg_en     <= 1'b1;  // Check the wb_error bit
          out_reg_data_sel <= 1'b0;  // select TILELINK data
          out_reg_ld_en    <= 1'b1;
          bit_ct_rst       <= 1'b1;
          word_ct_sel      <= 1'b1;
          word_ct_en       <= 1'b1;
          if (!(decremented_word_count == 0) && !word_count_zero) begin  // Start a tl read transaction
            wb_strobe <= 1'b1;
            addr_sel   <= 1'b1;
            addr_ct_en <= 1'b1;
          end
        end
      end
      `STATE_Rcrc: begin
        // Just shift out the data, don't bother counting, we don't move on until update_dr_i
        tdo_output_sel <= 2'h3;
        crc_shift_en   <= 1'b1;
        top_inhibit_o  <= 1'b1;
      end
      `STATE_Wready: ;  // Just a wait state
      `STATE_Wwait: begin
        tdo_output_sel <= 2'h1;
        top_inhibit_o  <= 1'b1;  // in case of early termination
        if (module_next_state == `STATE_Wburst) begin
          wb_clr_err <= 1'b1;  // If error occurred on last transaction of last burst, wb_err is still set.  Clear it.
          bit_ct_en   <= 1'b1;
          word_ct_sel <= 1'b1;  // Pre-decrement the byte count
          word_ct_en  <= 1'b1;
          crc_en      <= 1'b1;  // CRC gets tdi_i, which is 1 cycle ahead of data_register_i, so we need the bit there now in the CRC
          crc_in_sel  <= 1'b1;  // read data from tdi_i
        end
      end
      `STATE_Wburst: begin
        bit_ct_en      <= 1'b1;
        tdo_output_sel <= 2'h1;
        crc_en         <= 1'b1;
        crc_in_sel     <= 1'b1;  // read data from tdi_i
        top_inhibit_o  <= 1'b1;  // in case of early termination
        // It would be better to do this in STATE_Wstatus, but we don't use that state 
        // if ADBG_USE_HISPEED is defined.  
        if (ADBG_USE_HISPEED != "NONE" && bit_count_max) begin
          error_reg_en <= 1'b1;  // Check the wb_error bit
          bit_ct_rst   <= 1'b1;  // Zero the bit count
          // start transaction. Can't do this here if not hispeed, wb_ready
          // is the status bit, and it's 0 if we start a transaction here.
          wb_strobe   <= 1'b1;  // Start a TILELINK transaction
          addr_ct_en   <= 1'b1;  // Increment thte address counter
          // Also can't dec the byte count yet unless hispeed,
          // that would skip the last word.
          word_ct_sel  <= 1'b1;  // Decrement the byte count
          word_ct_en   <= 1'b1;
        end
      end
      `STATE_Wstatus: begin
        tdo_output_sel <= 2'h0;  // Send the status bit to TDO
        error_reg_en   <= 1'b1;  // Check the wb_error bit
        // start transaction
        wb_strobe     <= 1'b1;  // Start a TILELINK transaction
        word_ct_sel    <= 1'b1;  // Decrement the byte count
        word_ct_en     <= 1'b1;
        bit_ct_rst     <= 1'b1;  // Zero the bit count
        addr_ct_en     <= 1'b1;  // Increment thte address counter
        top_inhibit_o  <= 1'b1;  // in case of early termination
      end
      `STATE_Wcrc: begin
        bit_ct_en     <= 1'b1;
        top_inhibit_o <= 1'b1;  // in case of early termination
        if (module_next_state == `STATE_Wmatch) begin
          tdo_output_sel <= 2'h2;  // This is when the 'match' bit is actually read
        end
      end
      `STATE_Wmatch: begin
        tdo_output_sel <= 2'h2;
        top_inhibit_o  <= 1'b1;
        // Bit of a hack here...an error on the final write won't be detected in STATE_Wstatus like the rest, 
        // so we assume the bus transaction is done and check it / latch it into the error register here.
        if (module_next_state == `STATE_idle) begin
          error_reg_en <= 1'b1;
        end
      end
      default: begin
      end
    endcase
  end
endmodule
