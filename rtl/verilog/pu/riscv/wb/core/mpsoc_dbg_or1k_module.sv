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
//              AMBA3 AHB-Lite Bus Interface                                  //
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

`include "mpsoc_dbg_pkg.sv"

// Module interface
module mpsoc_dbg_or1k_module #(
  parameter X              = 2,
  parameter Y              = 2,
  parameter Z              = 2,
  parameter CORES_PER_TILE = 1,
  parameter CPU_ADDR_WIDTH = 32,
  parameter CPU_DATA_WIDTH = 32,

  parameter DBG_OR1K_DATAREG_LEN = 64
)
  (
    // JTAG signals
    input  logic                            tck_i,
    output logic                            module_tdo_o,
    input  logic                            tdi_i,

    // TAP states
    input  logic                            tlr_i,
    input  logic                            capture_dr_i,
    input  logic                            shift_dr_i,
    input  logic                            update_dr_i,

    input  logic [DBG_OR1K_DATAREG_LEN-1:0] data_register_i,
    input  logic                            module_select_i,
    output logic                            top_inhibit_o,

    // Interface to debug unit
    input                                                                      cpu_clk_i, 
    input                                                                      cpu_rstn_i,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_ADDR_WIDTH-1:0] cpu_addr_o,
    input  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] cpu_data_i,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] cpu_data_o,
    input  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_bp_i,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_stall_o,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_stb_o,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_we_o,
    input  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_ack_i
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  //FSM states
  localparam STATE_IDLE    = 4'b1011;
  localparam STATE_RBEGIN  = 4'b1010;
  localparam STATE_RREADY  = 4'b1001;
  localparam STATE_RSTATUS = 4'b1000;
  localparam STATE_RBURST  = 4'b0111;
  localparam STATE_WREADY  = 4'b0110;
  localparam STATE_WWAIT   = 4'b0101;
  localparam STATE_WBURST  = 4'b0100;
  localparam STATE_WSTATUS = 4'b0011;
  localparam STATE_RCRC    = 4'b0010;
  localparam STATE_WCRC    = 4'b0001;
  localparam STATE_WMATCH  = 4'b0000;

  localparam BIU_READY = 2'b11;
  localparam DATA_OUT  = 2'b10;
  localparam CRC_MATCH = 2'b01;
  localparam CRC_OUT   = 2'b00;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Registers to hold state etc.
  reg  [                       31:0] address_counter;          // Holds address for next CPU access
  reg  [                        5:0] bit_count;                // How many bits have been shifted in/out
  reg  [                       15:0] word_count;               // bytes remaining in current burst command
  reg  [                        3:0] operation;                // holds the current command (rd/wr, word size)
  reg  [                       31:0] data_out_shift_reg;       // parallel-load output shift register
  reg  [`DBG_OR1K_REGSELECT_LEN-1:0] internal_register_select; // Holds index of currently selected register

  wire [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] internal_reg_status;  // Holds CPU stall and reset status - signal is output of separate module


  // Control signals for the various counters / registers / state machines
  reg                               addr_sel;          // Selects data for address_counter. 0 = data_register_i, 1 = incremented address count
  reg                               addr_ct_en;        // Enable signal for address counter register
  reg                               op_reg_en;         // Enable signal for 'operation' register
  reg                               bit_ct_en;         // enable bit counter
  reg                               bit_ct_rst;        // reset (zero) bit count register
  reg                               word_ct_sel;       // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
  reg                               word_ct_en;        // Enable byte counter register
  reg                               out_reg_ld_en;     // Enable parallel load of data_out_shift_reg
  reg                               out_reg_shift_en;  // Enable shift of data_out_shift_reg
  reg                               out_reg_data_sel;  // 0 = BIU data, 1 = internal register data
  logic [1:0]                       tdo_output_sel;    // Selects signal to send to TDO.  0 = ready bit, 1 = output register, 2 = CRC match, 3 = CRC shift reg.
  reg                               biu_strobe;        // Indicates that the bus unit should latch data and start a transaction
  reg                               crc_clr;           // resets CRC module
  reg                               crc_en;            // does 1-bit iteration in CRC module
  reg                               crc_in_sel;        // selects incoming write data (=0) or outgoing read data (=1)as input to CRC module
  reg                               crc_shift_en;      // CRC reg is also it's own output shift register; this enables a shift
  reg                               regsel_ld_en;      // Reg. select register load enable
  reg                               intreg_ld_en;      // load enable for internal registers
  reg                               cpusel_ld_en;


  // Status signals
  wire                              word_count_zero;    // true when byte counter is zero
  wire                              bit_count_max;      // true when bit counter is equal to current word size
  wire                              module_cmd;         // inverse of MSB of data_register_i. 1 means current cmd not for top level (but is for us)
  wire                              biu_ready;          // indicates that the BIU has finished the last command
  wire                              burst_instruction;  // True when the input_data_i reg has a valid burst instruction for this module
  wire                              intreg_instruction; // True when the input_data_i reg has a valid internal register instruction
  wire                              intreg_write;       // True when the input_data_i reg has an internal register write op
  wire                              rd_op;              // True when operation in the opcode reg is a read, false when a write
  wire                              crc_match;          // indicates whether data_register_i matches computed CRC
  wire                              bit_count_32;       // true when bit count register == 32, for CRC after burst writes

  // Intermediate signals
  wire [                        5:0] word_size_bits;         // 8,16, or 32.  Decoded from 'operation'
  wire [                        2:0] address_increment;      // How much to add to the address counter each iteration
  wire [                       31:0] data_to_addr_counter;   // output of the mux in front of the address counter inputs
  wire [                       15:0] data_to_word_counter;   // output of the mux in front of the byte counter input
  wire [                       15:0] decremented_word_count;
  wire [                       31:0] address_data_in;        // from data_register_i
  wire [                       15:0] count_data_in;          // from data_register_i
  wire [                        3:0] operation_in;           // from data_register_i
  wire [                       31:0] data_to_biu;            // from data_register_i
  wire [                       31:0] data_from_biu;          // to data_out_shift_register
  wire [                       31:0] crc_data_out;           // output of CRC module, to output shift register
  wire                               crc_data_in;            // input to CRC module, either data_register_i[52] or data_out_shift_reg[0]
  wire                               crc_serial_out;
  wire [`DBG_OR1K_REGSELECT_LEN-1:0] reg_select_data;        // from data_register_i, input to internal register select register
  wire [                       31:0] out_reg_data;           // parallel input to the output shift register
  reg  [                       31:0] data_from_internal_reg; // data from internal reg. MUX to output shift register
  wire                               status_reg_wr;

  logic [         3:0] cpu_select;
  logic [         3:0] cpu_select_in;

  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0] status_reg_data;

  //FSM states
  logic [3:0] module_state, module_next_state;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  // Combinatorial assignments
  assign module_cmd      =   ~data_register_i[DBG_OR1K_DATAREG_LEN- 1      ];
  assign operation_in    =    data_register_i[DBG_OR1K_DATAREG_LEN- 2 -:  4];
  assign cpu_select_in   =    data_register_i[DBG_OR1K_DATAREG_LEN- 6 -:  4];
  assign address_data_in =    data_register_i[DBG_OR1K_DATAREG_LEN-10 -: 32];
  assign count_data_in   =    data_register_i[DBG_OR1K_DATAREG_LEN-42 -: 16];

  assign data_to_biu     = {tdi_i,data_register_i[DBG_OR1K_DATAREG_LEN-1 -: 31]};

  assign reg_select_data = data_register_i[DBG_OR1K_DATAREG_LEN - 6                         -: `DBG_OR1K_REGSELECT_LEN];
  assign status_reg_data = data_register_i[DBG_OR1K_DATAREG_LEN -10 -`DBG_OR1K_REGSELECT_LEN -: X*Y*Z*CORES_PER_TILE]; //data is sent first, then module_cmd, operation, cpu_select

  ////////////////////////////////////////////////
  // Operation decoder

  // These are only used before the operation is latched, so decode them from operation_in
  assign burst_instruction  = (operation_in == `DBG_OR1K_CMD_BWRITE32) | (operation_in == `DBG_OR1K_CMD_BREAD32);
  assign intreg_instruction = (operation_in == `DBG_OR1K_CMD_IREG_WR)  | (operation_in == `DBG_OR1K_CMD_IREG_SEL);
  assign intreg_write       = (operation_in == `DBG_OR1K_CMD_IREG_WR);

  // These are constant, the CPU module only does 32-bit accesses
  assign word_size_bits    = 'd31; // Bits is actually bits-1, to make the FSM easier
  assign address_increment = 'd1;  // This is only used to increment the address.  SPRs are word-addressed.

  // This is the only thing that actually needs to be saved and 'decoded' from the latched opcode
  // It goes to the BIU each time a transaction is started.
  assign rd_op = operation[2];

  // Module-internal register select register (no, that's not redundant.)
  // Also internal register output MUX
  always @(posedge tck_i,posedge tlr_i) begin
    if      (tlr_i       ) internal_register_select <= 'h0;
    else if (regsel_ld_en) internal_register_select <= reg_select_data;
  end

  ////////////////////////////////////////////////
  // CPU select register
  //
  always @(posedge tck_i,posedge tlr_i) begin
    if      (tlr_i       ) cpu_select <= 'h0;
    else if (cpusel_ld_en) cpu_select <= cpu_select_in;
  end

  // This is completely unnecessary here, since the module has only 1 internal
  // register.  However, to make the module expandable, it is included anyway.
  always @(*) begin
    case(internal_register_select)
      `DBG_OR1K_INTREG_STATUS:
        data_from_internal_reg = {{($bits(data_from_internal_reg)-X*Y*Z*CORES_PER_TILE){1'b0}}, internal_reg_status};
      default:
        data_from_internal_reg = {{($bits(data_from_internal_reg)-X*Y*Z*CORES_PER_TILE){1'b0}}, internal_reg_status};
    endcase
  end

  // Module-internal registers
  // These have generic read/write/select code, but
  // individual registers may have special behavior, defined here.

  // This is the status register, which holds the reset and stall states.
  assign status_reg_wr = (intreg_ld_en & (reg_select_data == `DBG_OR1K_INTREG_STATUS));

  mpsoc_dbg_or1k_status_reg #(
    .X              ( X              ),
    .Y              ( Y              ),
    .Z              ( Z              ),
    .CORES_PER_TILE ( CORES_PER_TILE )
  )
  or1k_statusreg_i (
    .tck_i       ( tck_i               ),
    .tlr_i       ( tlr_i               ),
    .data_i      ( status_reg_data     ),
    .we_i        ( status_reg_wr       ),
    .bp_i        ( cpu_bp_i            ),
    .cpu_clk_i   ( cpu_clk_i           ),
    .cpu_rstn_i  ( cpu_rstn_i          ),
    .ctrl_reg_o  ( internal_reg_status ),
    .cpu_stall_o ( cpu_stall_o         )
  );

  // Address counter
  assign data_to_addr_counter = addr_sel ? address_counter + address_increment : address_data_in;

  // Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  // negedge, per the JTAG spec. But that makes things difficult when incrementing.
  always @(posedge tck_i,posedge tlr_i) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if      (tlr_i     ) address_counter <= 'h0;
    else if (addr_ct_en) address_counter <= data_to_addr_counter;
  end

  // Opcode latch
  always @(posedge tck_i,posedge tlr_i) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if      (tlr_i    ) operation <= 'h0;
    else if (op_reg_en) operation <= operation_in;
  end

  // Bit counter
  always @(posedge tck_i,posedge tlr_i) begin
    if      (tlr_i     ) bit_count <= 'h0;
    else if (bit_ct_rst) bit_count <= 'h0;
    else if (bit_ct_en ) bit_count <= bit_count + 'h1;
  end

  assign bit_count_max = (bit_count == word_size_bits);
  assign bit_count_32  = (bit_count == 'd32);

  // Word counter
  assign data_to_word_counter   = word_ct_sel ?  decremented_word_count : count_data_in;
  assign decremented_word_count = word_count - 'h1;

  // Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  // negedge, per the JTAG spec. But that makes things difficult when incrementing.
  always @(posedge tck_i,posedge tlr_i) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if      (tlr_i     ) word_count <= 'h0;
    else if (word_ct_en) word_count <= data_to_word_counter;
  end

  assign word_count_zero = ~|word_count;

  // Output register and TDO output MUX
  assign out_reg_data = out_reg_data_sel ? data_from_internal_reg : data_from_biu;

  always @(posedge tck_i or posedge tlr_i) begin
    if      (tlr_i           ) data_out_shift_reg <= 'h0;
    else if (out_reg_ld_en   ) data_out_shift_reg <= out_reg_data;
    else if (out_reg_shift_en) data_out_shift_reg <= {1'b0, data_out_shift_reg[31:1]};
  end

  always @(*) begin
    case (tdo_output_sel)
      BIU_READY : module_tdo_o = biu_ready;
      DATA_OUT  : module_tdo_o = data_out_shift_reg[0];
      CRC_MATCH : module_tdo_o = crc_match;
      default   : module_tdo_o = crc_serial_out;
    endcase
  end

  // Bus Interface Unit (to OR1K SPR bus)
  // It is assumed that the BIU has internal registers, and will
  // latch address, operation, and write data on rising clock edge
  // when strobe is asserted
  mpsoc_dbg_or1k_biu #(
    .X              ( X              ),
    .Y              ( Y              ),
    .Z              ( Z              ),
    .CORES_PER_TILE ( CORES_PER_TILE ),
    .CPU_ADDR_WIDTH ( CPU_ADDR_WIDTH ),
    .CPU_DATA_WIDTH ( CPU_DATA_WIDTH )
  )
  or1k_biu_i (
    // Debug interface signals
    .tck_i        ( tck_i           ),
    .tlr_i        ( tlr_i           ),
    .cpu_select_i ( cpu_select      ),
    .data_i       ( data_to_biu     ),
    .data_o       ( data_from_biu   ),
    .addr_i       ( address_counter ),
    .strobe_i     ( biu_strobe      ),
    .rd_wrn_i     ( rd_op           ),  // If 0, then write op
    .rdy_o        ( biu_ready       ),
    //  This bus has no error signal

    // OR1K SPR bus signals
    .cpu_clk_i    ( cpu_clk_i       ),
    .cpu_rstn_i   ( cpu_rstn_i      ),
    .cpu_addr_o   ( cpu_addr_o      ),
    .cpu_data_i   ( cpu_data_i      ),
    .cpu_data_o   ( cpu_data_o      ),
    .cpu_stb_o    ( cpu_stb_o       ),
    .cpu_we_o     ( cpu_we_o        ),
    .cpu_ack_i    ( cpu_ack_i       )
  );

  // CRC module
  assign crc_data_in = (crc_in_sel) ? tdi_i : data_out_shift_reg[0];  // MUX, write or read data

  mpsoc_dbg_crc32 or1k_crc_i (
    .rstn       (~tlr_i          ),
    .clk        ( tck_i          ),
    .data       ( crc_data_in    ),
    .enable     ( crc_en         ),
    .shift      ( crc_shift_en   ),
    .clr        ( crc_clr        ),
    .crc_out    ( crc_data_out   ),
    .serial_out ( crc_serial_out )
  );

  assign crc_match = (data_register_i[DBG_OR1K_DATAREG_LEN-1 -: 32] == crc_data_out);

  // Control FSM

  // sequential part of the FSM
  always @(posedge tck_i,posedge tlr_i) begin
    if (tlr_i) module_state <= STATE_IDLE;
    else       module_state <= module_next_state;
  end

  // Determination of next state; purely combinatorial
  always @(*) begin
    case(module_state)
      STATE_IDLE: begin
        if(module_cmd && module_select_i && update_dr_i && burst_instruction) begin
          if (operation_in[2]) module_next_state = STATE_RBEGIN;
          else                 module_next_state = STATE_WREADY;
        end
        else                   module_next_state = STATE_IDLE;
      end
      STATE_RBEGIN: begin
        if (word_count_zero) module_next_state = STATE_IDLE;  // set up a burst of size 0, illegal.
        else                 module_next_state = STATE_RREADY;
      end
      STATE_RREADY: begin
        if (module_select_i && capture_dr_i) module_next_state = STATE_RSTATUS;
        else                                 module_next_state = STATE_RREADY;
      end
      STATE_RSTATUS: begin
        if      (update_dr_i) module_next_state = STATE_IDLE;
        else if (biu_ready  ) module_next_state = STATE_RBURST;
        else                  module_next_state = STATE_RSTATUS;
      end
      STATE_RBURST: begin
        if      (update_dr_i                     ) module_next_state = STATE_IDLE;
        else if (bit_count_max && word_count_zero) module_next_state = STATE_RCRC;
        else                                       module_next_state = STATE_RBURST;
      end
      STATE_RCRC: begin
        if (update_dr_i) module_next_state = STATE_IDLE;
        // This doubles as the 'recovery' state, so stay here until update_dr_i.
        else             module_next_state = STATE_RCRC;
      end
      STATE_WREADY: begin
        if      (word_count_zero                ) module_next_state = STATE_IDLE;
        else if (module_select_i && capture_dr_i) module_next_state = STATE_WWAIT;
        else                                      module_next_state = STATE_WREADY;
      end
      STATE_WWAIT: begin
        if      (update_dr_i                                               ) module_next_state = STATE_IDLE;  // client terminated early
        else if (module_select_i && data_register_i[DBG_OR1K_DATAREG_LEN-1]) module_next_state = STATE_WBURST; // Got a start bit
        else                                                                 module_next_state = STATE_WWAIT;
      end
      STATE_WBURST: begin
        if      (update_dr_i                     ) module_next_state = STATE_IDLE;  // client terminated early
        else if (bit_count_max && word_count_zero) module_next_state = STATE_WCRC;
        else                                       module_next_state = STATE_WBURST;
      end
      STATE_WSTATUS: begin
        if      (update_dr_i    ) module_next_state = STATE_IDLE;  // client terminated early
        else if (word_count_zero) module_next_state = STATE_WCRC;
        // can't wait until bus ready if multiple devices in chain...
        // Would have to read postfix_bits, then send another start bit and push it through
        // prefix_bits...potentially very inefficient.
        else                      module_next_state = STATE_WBURST;
      end
      STATE_WCRC: begin
        if      (update_dr_i ) module_next_state = STATE_IDLE;  // client terminated early
        else if (bit_count_32) module_next_state = STATE_WMATCH;
        else                   module_next_state = STATE_WCRC;
      end
      STATE_WMATCH: begin
        if (update_dr_i) module_next_state = STATE_IDLE;
        // This doubles as our recovery state, stay here until update_dr_i
        else             module_next_state = STATE_WMATCH;
      end
      default: module_next_state = STATE_IDLE;  // shouldn't actually happen...
    endcase
  end
  // Outputs of state machine, pure combinatorial
  always @(*) begin
    // Default everything to 0, keeps the case statement simple
    addr_sel         = 1'b1; // Selects data for address_counter. 0 = data_register_i, 1 = incremented address count
    addr_ct_en       = 1'b0; // Enable signal for address counter register
    op_reg_en        = 1'b0; // Enable signal for 'operation' register
    bit_ct_en        = 1'b0; // enable bit counter
    bit_ct_rst       = 1'b0; // reset (zero) bit count register
    word_ct_sel      = 1'b1; // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    word_ct_en       = 1'b0; // Enable byte counter register
    out_reg_ld_en    = 1'b0; // Enable parallel load of data_out_shift_reg
    out_reg_shift_en = 1'b0; // Enable shift of data_out_shift_reg
    tdo_output_sel   = DATA_OUT; // 1 = data reg, 0 = biu_ready, 2 = crc_match, 3 = CRC data
    biu_strobe       = 1'b0;
    crc_clr          = 1'b0;
    crc_en           = 1'b0; // add the input bit to the CRC calculation
    crc_in_sel       = 1'b0; // 0 = tdo, 1 = tdi
    crc_shift_en     = 1'b0;
    out_reg_data_sel = 1'b1; // 0 = BIU data, 1 = internal register data
    regsel_ld_en     = 1'b0;
    cpusel_ld_en     = 1'b0;
    intreg_ld_en     = 1'b0;
    top_inhibit_o    = 1'b0; // Don't disable the top-level module in the default case

    case(module_state)
      STATE_IDLE: begin
        addr_sel    = 1'b0;
        word_ct_sel = 1'b0;

        // Operations for internal registers - stay in idle state
        if (module_select_i & shift_dr_i) out_reg_shift_en = 1'b1; // For module regs
        if (module_select_i & capture_dr_i) begin
          out_reg_data_sel = 1'b1;  // select internal register data
          out_reg_ld_en    = 1'b1;   // For module regs
        end
        if(module_select_i & module_cmd & update_dr_i) begin
          if (intreg_instruction) regsel_ld_en = 1'b1;  // For module regs
          if (intreg_write)       intreg_ld_en = 1'b1;  // For module regs
          if (burst_instruction)  cpusel_ld_en = 1'b1;
        end

        // Burst operations
        if (module_next_state != STATE_IDLE) begin  // Do the same to receive read or write opcode
          addr_ct_en = 1'b1;
          op_reg_en  = 1'b1;
          bit_ct_rst = 1'b1;
          word_ct_en = 1'b1;
          crc_clr    = 1'b1;
        end
      end

      STATE_RBEGIN: begin
        if(!word_count_zero)
          begin  // Start a biu read transaction
            biu_strobe = 1'b1;
            addr_sel   = 1'b1;
            addr_ct_en = 1'b1;
          end
      end

      STATE_RREADY:  ; // Just a wait state

      STATE_RSTATUS: begin
        tdo_output_sel = BIU_READY;
        top_inhibit_o  = 1'b1;    // in case of early termination

        if (module_next_state == STATE_RBURST) begin
          out_reg_data_sel = 1'b0;  // select BIU data
          out_reg_ld_en    = 1'b1;
          bit_ct_rst       = 1'b1;
          word_ct_sel      = 1'b1;
          word_ct_en       = 1'b1;
          if(!(decremented_word_count == 0) && !word_count_zero) begin  // Start a biu read transaction
            biu_strobe = 1'b1;
            addr_sel   = 1'b1;
            addr_ct_en = 1'b1;
          end
        end
      end

      STATE_RBURST: begin
        tdo_output_sel   = DATA_OUT;
        out_reg_shift_en = 1'b1;
        bit_ct_en        = 1'b1;
        crc_en           = 1'b1;
        crc_in_sel       = 1'b0;  // read data in output shift register LSB (tdo)
        top_inhibit_o    = 1'b1;  // in case of early termination

        if(bit_count_max) begin
          out_reg_data_sel = 1'b0;  // select BIU data
          out_reg_ld_en    = 1'b1;
          bit_ct_rst       = 1'b1;
          word_ct_sel      = 1'b1;
          word_ct_en       = 1'b1;
          if(!(decremented_word_count == 0) && !word_count_zero)  // Start a biu read transaction
            begin
              biu_strobe = 1'b1;
              addr_sel   = 1'b1;
              addr_ct_en = 1'b1;
            end
        end
      end

      STATE_RCRC: begin
        // Just shift out the data, don't bother counting, we don't move on until update_dr_i
        tdo_output_sel = CRC_OUT;
        crc_shift_en   = 1'b1;
        top_inhibit_o  = 1'b1;
      end

      STATE_WREADY: ; // Just a wait state

      STATE_WWAIT: begin
        tdo_output_sel = DATA_OUT;
        top_inhibit_o  = 1'b1;    // in case of early termination
        if(module_next_state == STATE_WBURST)
          begin
            bit_ct_en   = 1'b1;
            word_ct_sel = 1'b1;  // Pre-decrement the byte count
            word_ct_en  = 1'b1;
            crc_en      = 1'b1;  // CRC gets tdi_i, which is 1 cycle ahead of data_register_i, so we need the bit there now in the CRC
            crc_in_sel  = 1'b1;  // read data from tdi_i
          end
      end

      STATE_WBURST: begin
        bit_ct_en      = 1'b1;
        tdo_output_sel = DATA_OUT;
        crc_en         = 1'b1;
        crc_in_sel     = 1'b1;  // read data from tdi_i
        top_inhibit_o  = 1'b1;    // in case of early termination

        // It would be better to do this in STATE_WSTATUS, but we don't use that state
        // if mpsoc_dbg_USE_HISPEED is defined.
        if(bit_count_max) begin
          bit_ct_rst = 1'b1;  // Zero the bit count

          // start transaction. Can't do this here if not hispeed, biu_ready
          // is the status bit, and it's 0 if we start a transaction here.
          biu_strobe = 1'b1;  // Start a BIU transaction
          addr_ct_en = 1'b1;  // Increment thte address counter

          // Also can't dec the byte count yet unless hispeed,
          // that would skip the last word.
          word_ct_sel = 1'b1;  // Decrement the byte count
          word_ct_en  = 1'b1;
        end
      end

      STATE_WSTATUS: begin
        tdo_output_sel = BIU_READY; // Send the status bit to TDO

        // start transaction
        biu_strobe    = 1'b1;  // Start a BIU transaction
        word_ct_sel   = 1'b1;  // Decrement the byte count
        word_ct_en    = 1'b1;
        bit_ct_rst    = 1'b1;  // Zero the bit count
        addr_ct_en    = 1'b1;  // Increment thte address counter
        top_inhibit_o = 1'b1;  // in case of early termination
      end

      STATE_WCRC: begin
        bit_ct_en     = 1'b1;
        top_inhibit_o = 1'b1;    // in case of early termination
        if (module_next_state == STATE_WMATCH) tdo_output_sel = CRC_MATCH;  // This is when the 'match' bit is actually read
      end

      STATE_WMATCH: begin
        tdo_output_sel = CRC_MATCH;
        top_inhibit_o  = 1'b1;    // in case of early termination
      end

      default: ;
    endcase
  end
endmodule
