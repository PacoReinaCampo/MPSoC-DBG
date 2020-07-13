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

module mpsoc_dbg_bus_module_core #(
  //parameter such that these can be pushed down from the higher level
  //higher level will either read these from a package or get them as parameters

  //Data + Address width
  parameter ADDR_WIDTH     = 32,
  parameter DATA_WIDTH     = 32,

  //Data register size (function of ADDR_WIDTH)
  parameter DATAREG_LEN    = 64
)
  (
    input                        dbg_clk,
    input                        dbg_rst,
    input                        dbg_tdi,
    output reg                   dbg_tdo,

    // TAP states
    input                        capture_dr_i,
    input                        shift_dr_i,
    input                        update_dr_i,

    input      [DATAREG_LEN-1:0] data_register,  // the data register is at top level, shared between all modules
    input                        module_select,
    output reg                   inhibit,

    //Bus Interface Unit ports
    output                       biu_clk,
    output                       biu_rst, //BIU reset
    output     [DATA_WIDTH -1:0] biu_di,  //data towards BIU
    input      [DATA_WIDTH -1:0] biu_do,  //data from BIU
    output     [ADDR_WIDTH -1:0] biu_addr,
    output                       biu_strb,
    output                       biu_rw,
    input                        biu_rdy,
    input                        biu_err,
    output     [            3:0] biu_word_size
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  //Instructions
  parameter BWRITE8        = 4'h1;
  parameter BWRITE16       = 4'h2;
  parameter BWRITE32       = 4'h3;
  parameter BWRITE64       = 4'h4;
  parameter BREAD8         = 4'h5;
  parameter BREAD16        = 4'h6;
  parameter BREAD32        = 4'h7;
  parameter BREAD64        = 4'h8;
  parameter IREG_WR        = 4'h9;
  parameter IREG_SEL       = 4'hd;

  parameter REGSELECT_SIZE = 1;

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

  localparam INTREG_ERROR = 1'b0;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Registers to hold state etc.
  logic [ADDR_WIDTH    -1:0] address_counter;           // Holds address for next Wishbone access
  logic [               5:0] bit_count;                 // How many bits have been shifted in/out
  logic [              15:0] word_count;                // bytes remaining in current burst command
  logic [DATA_WIDTH      :0] data_out_shift_reg;        // 32 bits to accomodate the internal_reg_error
  logic [REGSELECT_SIZE-1:0] internal_register_select;  // Holds index of currently selected register
  logic [ADDR_WIDTH      :0] internal_reg_error;        // WB error module internal register.  32 bit address + error bit (LSB)

  // Control signals for the various counters / registers / state machines
  logic                     addr_sel;         // Selects data for address_counter. 0=data_register_i, 1=incremented address count
  logic                     addr_ct_en;       // Enable signal for address counter register
  logic                     op_reg_en;        // Enable signal for 'operation' register
  logic                     bit_ct_en;        // enable bit counter
  logic                     bit_ct_rst;       // reset (zero) bit count register
  logic                     word_ct_sel;      // Selects data for byte counter.  0=data_register_i, 1=decremented byte count
  logic                     word_ct_en;       // Enable byte counter register
  logic                     out_reg_ld_en;    // Enable parallel load of data_out_shift_reg
  logic                     out_reg_shift_en; // Enable shift of data_out_shift_reg
  logic                     out_reg_data_sel; // 0 = BIU data, 1 = internal register data
  reg   [1:0]               tdo_output_sel;   // Selects signal to send to TDO. 0=ready bit, 1=output register, 2=CRC match, 3=CRC shift reg.
  logic                     biu_strobe;       // Indicates that the bus unit should latch data and start a transaction
  logic                     crc_clr;          // resets CRC module
  logic                     crc_en;           // does 1-bit iteration in CRC module
  logic                     crc_in_sel;       // selects incoming write data (=0) or outgoing read data (=1)as input to CRC module
  logic                     crc_shift_en;     // CRC reg is also it's own output shift register; this enables a shift
  logic                     regsel_ld_en;     // Reg. select register load enable
  logic                     intreg_ld_en;     // load enable for internal registers
  logic                     error_reg_en;     // Tells the error register to check for and latch a bus error
  logic                     biu_clr_err;      // Allows FSM to reset BIU, to clear the biu_err bit which may have been set on the last transaction of the last burst.

  // Status signals
  wire                      word_count_zero;    // true when byte counter is zero
  wire                      bit_count_max;      // true when bit counter is equal to current word size
  wire                      module_cmd;         // inverse of MSB of data_register. 1 means current cmd not for top level (but is for us)
  logic                     burst_read;
  logic                     burst_write;
  wire                      intreg_instruction; // True when the input_data reg has a valid internal register instruction
  wire                      intreg_write;       // True when the input_data reg has an internal register write op
  reg                       rd_op;              // True when operation in the opcode reg is a read, false when a write
  wire                      crc_match;          // indicates whether data_register matches computed CRC
  wire                      bit_count_32;       // true when bit count register == 32, for CRC after burst writes

  // Intermediate signals
  logic [               5:0] word_size_bits;        // 8,16,32,64.  Decoded from 'operation'
  logic [               3:0] word_size_bytes;       // 1,2,4,8
  logic [              15:0] decremented_word_count;
  logic [ADDR_WIDTH    -1:0] address_data_in;       // from data_register_i
  logic [              15:0] count_data_in;         // from data_register_i
  logic [               3:0] operation_in;          // from data_register_i
  logic [DATA_WIDTH    -1:0] data_to_biu;           // from data_register_i
  logic [              31:0] crc_data_out;          // output of CRC module, to output shift register
  logic                      crc_data_in;           // input to CRC module, either data_register[52] or data_out_shift_reg[0]
  logic                      crc_serial_out;
  logic [REGSELECT_SIZE-1:0] reg_select_data; // from data_register_i, input to internal register select register
  logic [DATA_WIDTH      :0] data_from_internal_reg;  // data from internal reg. MUX to output shift register

  //Statemachine states
  logic [3:0] module_state, module_next_state;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // Combinatorial assignments
  assign module_cmd      =~data_register[DATAREG_LEN-1                         ];
  assign operation_in    = data_register[DATAREG_LEN-2            -:          4];
  assign address_data_in = data_register[DATAREG_LEN-6            -: ADDR_WIDTH];
  assign count_data_in   = data_register[DATAREG_LEN-6-ADDR_WIDTH -:         16];

  assign data_to_biu     = {dbg_tdi,data_register[DATAREG_LEN-1  -:  DATA_WIDTH-1]};

  assign reg_select_data = data_register[DATAREG_LEN-6  -: REGSELECT_SIZE];

  // Operation decoder

  // These are only used before the operation is latched, so decode them from operation_in
  assign intreg_instruction = (operation_in == IREG_WR) | (operation_in == IREG_SEL);
  assign intreg_write       = (operation_in == IREG_WR);

  assign burst_write        = (operation_in == BWRITE8)  | 
                              (operation_in == BWRITE16) | 
                              (operation_in == BWRITE32) | 
                              (operation_in == BWRITE64); 

  assign burst_read         = (operation_in == BREAD8)  | 
                              (operation_in == BREAD16) | 
                              (operation_in == BREAD32) | 
                              (operation_in == BREAD64); 

  // This is decoded from the registered operation
  always @(posedge dbg_clk) begin
    if (op_reg_en) begin
      case(operation_in)
        BWRITE8 : begin
          word_size_bits  <= 'd7;  // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd1;
          rd_op           <= 'b0;
        end
        BWRITE16: begin
          word_size_bits  <= 'd15; // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd2;
          rd_op           <= 'b0;
        end
        BWRITE32: begin
          word_size_bits  <= 'd31; // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd4;
          rd_op           <= 'b0;
        end
        BWRITE64: begin
          word_size_bits  <= 'd63; // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd8;
          rd_op           <= 'b0;
        end
        BREAD8  : begin
          word_size_bits  <= 'd7;  // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd1;
          rd_op           <= 'b1;
        end
        BREAD16 : begin
          word_size_bits  <= 'd15; // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd2;
          rd_op           <= 'b1;
        end
        BREAD32 : begin
          word_size_bits  <= 'd31; // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd4;
          rd_op           <= 'b1;
        end
        BREAD64 : begin
          word_size_bits  <= 'd63; // Bits is actually bits-1, to make the FSM easier
          word_size_bytes <= 'd8;
          rd_op           <= 'b1;
        end
        default:  begin
          word_size_bits  <= 'hx;
          word_size_bytes <= 'hx;
          rd_op           <= 'bx;
        end       
      endcase
    end
  end

  // Module-internal register select register (no, that's not redundant.)
  // Also internal register output MUX
  always @(posedge dbg_clk,posedge dbg_rst) begin
    if      (dbg_rst     ) internal_register_select = 1'h0;
    else if (regsel_ld_en) internal_register_select = reg_select_data;
  end

  // This is completely unnecessary here, since the WB module has only 1 internal register
  // However, to make the module expandable, it is included anyway.
  always @(*) begin
    case(internal_register_select) 
      INTREG_ERROR: data_from_internal_reg = internal_reg_error;
      default     : data_from_internal_reg = internal_reg_error;
    endcase
  end

  // Module-internal registers
  // These have generic read/write/select code, but
  // individual registers may have special behavior, defined here.

  // This is the bus error register, which traps WB errors
  // We latch every new BIU address in the upper 32 bits, so we always have the address for the transaction which
  // generated the error (the address counter might increment, esp. for writes)
  // We stop latching addresses when the error bit (bit 0) is set. Keep the error bit set until it is 
  // manually cleared by a module internal register write.
  // Note we use reg_select_data straight from data_register_i, rather than the latched version - 
  // otherwise, we would write the previously selected register.
  always @(posedge dbg_clk,posedge dbg_rst) begin
    if (dbg_rst) internal_reg_error <= 'h0;
    else if (intreg_ld_en && (reg_select_data == INTREG_ERROR)) begin  // do load from data input register
      if (data_register[46]) internal_reg_error[0] <= 1'b0;  // if write data is 1, reset the error bit  TODO:fix 46
    end
    else if (error_reg_en && !internal_reg_error[0]) begin
      if      (biu_err || !biu_rdy) internal_reg_error[0]            <= 1'b1;	    
      else if (biu_strobe         ) internal_reg_error[DATA_WIDTH:1] <= address_counter;
    end
    else if (biu_strobe && !internal_reg_error[0])
      internal_reg_error[DATA_WIDTH:1] <= address_counter;  // When no error, latch this whether error_reg_en or not
  end

  // Address counter

  // Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  // negedge, per the JTAG spec. But that makes things difficult when incrementing.
  always @ (posedge dbg_clk,posedge dbg_rst) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if      (dbg_rst   ) address_counter <= 'h0;
    else if (addr_ct_en) address_counter <= addr_sel ? address_counter + word_size_bytes : address_data_in;
  end

  // Bit counter
  always @(posedge dbg_clk,posedge dbg_rst) begin
    if      (dbg_rst   ) bit_count <= 'h0;
    else if (bit_ct_rst) bit_count <= 'h0;
    else if (bit_ct_en ) bit_count <= bit_count + 'h1;
  end

  assign bit_count_max = bit_count == word_size_bits;
  assign bit_count_32  = bit_count == 'd32;

  // Word counter
  assign decremented_word_count = word_count - 'h1;

  // Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  // negedge, per the JTAG spec. But that makes things difficult when incrementing.
  always @(posedge dbg_clk,posedge dbg_rst) begin  // JTAG spec specifies latch on negative edge in UPDATE_DR state
    if      (dbg_rst   ) word_count <= 'h0;
    else if (word_ct_en) word_count <= word_ct_sel ?  decremented_word_count : count_data_in; 
  end

  assign word_count_zero = ~|word_count;

  // Output register and TDO output MUX
  always @(posedge dbg_clk,posedge dbg_rst) begin
    if      (dbg_rst         ) data_out_shift_reg <= 'h0;
    else if (out_reg_ld_en   ) data_out_shift_reg <= out_reg_data_sel ? data_from_internal_reg : {1'b0,biu_do};
    else if (out_reg_shift_en) data_out_shift_reg <= {1'b0, data_out_shift_reg[$bits(data_out_shift_reg)-1:1]};
  end

  always @(*) begin
    case (tdo_output_sel)
      2'h0   : dbg_tdo = biu_rdy;
      2'h1   : dbg_tdo = data_out_shift_reg[0];
      2'h2   : dbg_tdo = crc_match;
      default: dbg_tdo = crc_serial_out;
    endcase
  end

  // Bus Interface Unit
  // It is assumed that the BIU has internal registers, and will
  // latch address, operation, and write data on rising clock edge 
  // when strobe is asserted
  assign biu_clk       = dbg_clk;
  assign biu_rst       = dbg_rst | biu_clr_err;
  assign biu_di        = data_to_biu;
  assign biu_addr      = address_counter;
  assign biu_strb      = biu_strobe;
  assign biu_rw        = rd_op;
  assign biu_word_size = word_size_bytes;

  // CRC module

  assign crc_data_in = crc_in_sel ? dbg_tdi : data_out_shift_reg[0];  // MUX, write or read data

  mpsoc_dbg_crc32 wb_crc_i (
    .rstn       (~dbg_rst        ),
    .clk        ( dbg_clk        ), 
    .data       ( crc_data_in    ),
    .enable     ( crc_en         ),
    .shift      ( crc_shift_en   ),
    .clr        ( crc_clr        ),
    .crc_out    ( crc_data_out   ),
    .serial_out ( crc_serial_out ) );

  assign crc_match = data_register[DATAREG_LEN-1 -: 32] == crc_data_out;

  // Control FSM

  // sequential part of the FSM
  always @(posedge dbg_clk,posedge dbg_rst) begin
    if   (dbg_rst) module_state <= STATE_IDLE;
    else           module_state <= module_next_state;
  end

  // Determination of next state; purely combinatorial
  always @(*) begin
    case(module_state)
      STATE_IDLE: begin
        if      (module_cmd && module_select && update_dr_i && burst_read ) module_next_state = STATE_RBEGIN;
        else if (module_cmd && module_select && update_dr_i && burst_write) module_next_state = STATE_WREADY;
        else                                                                module_next_state = STATE_IDLE;
      end
      STATE_RBEGIN: begin
        if (word_count_zero) module_next_state = STATE_IDLE;  // set up a burst of size 0, illegal.
        else                 module_next_state = STATE_RREADY;
      end
      STATE_RREADY: begin
        if (module_select && capture_dr_i) module_next_state = STATE_RSTATUS;
        else                               module_next_state = STATE_RREADY;
      end
      STATE_RSTATUS: begin
        if      (update_dr_i) module_next_state = STATE_IDLE; 
        else if (biu_rdy    ) module_next_state = STATE_RBURST;
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
        if      (word_count_zero              ) module_next_state = STATE_IDLE;
        else if (module_select && capture_dr_i) module_next_state = STATE_WWAIT;
        else                                    module_next_state = STATE_WREADY;
      end
      STATE_WWAIT: begin
        if      (update_dr_i                                  ) module_next_state = STATE_IDLE;  // client terminated early
        else if (module_select && data_register[DATAREG_LEN-1]) module_next_state = STATE_WBURST; // Got a start bit
        else                                                    module_next_state = STATE_WWAIT;
      end
      STATE_WBURST: begin
        if      (update_dr_i  )   module_next_state = STATE_IDLE;  // client terminated early
        else if (bit_count_max)
          if    (word_count_zero) module_next_state = STATE_WCRC;
        else                      module_next_state = STATE_WBURST;
        else                      module_next_state = STATE_WBURST;
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
      default:           module_next_state = STATE_IDLE;  // shouldn't actually happen...
    endcase
  end

  // Outputs of state machine, pure combinatorial
  always @(*) begin
    // Default everything to 0, keeps the case statement simple
    addr_sel         = 1'b1;  // Selects data for address_counter. 0 = data_register_i, 1 = incremented address count
    addr_ct_en       = 1'b0;  // Enable signal for address counter register
    op_reg_en        = 1'b0;  // Enable signal for 'operation' register
    bit_ct_en        = 1'b0;  // enable bit counter
    bit_ct_rst       = 1'b0;  // reset (zero) bit count register
    word_ct_sel      = 1'b1;  // Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    word_ct_en       = 1'b0;  // Enable byte counter register
    out_reg_ld_en    = 1'b0;  // Enable parallel load of data_out_shift_reg
    out_reg_shift_en = 1'b0;  // Enable shift of data_out_shift_reg
    tdo_output_sel   = 2'b1;  // 1 = data reg, 0 = biu_rdy, 2 = crc_match, 3 = CRC data
    biu_strobe       = 1'b0;
    crc_clr          = 1'b0;
    crc_en           = 1'b0;  // add the input bit to the CRC calculation
    crc_in_sel       = 1'b0;  // 0 = tdo, 1 = tdi
    crc_shift_en     = 1'b0;
    out_reg_data_sel = 1'b1;  // 0 = BIU data, 1 = internal register data
    regsel_ld_en     = 1'b0;
    intreg_ld_en     = 1'b0;
    error_reg_en     = 1'b0;
    biu_clr_err      = 1'b0;  // Set this to reset the BIU, clearing the biu_err bit
    inhibit          = 1'b0;  // Don't disable the top-level module in the default case

    case (module_state)
      STATE_IDLE: begin
        addr_sel    = 1'b0;
        word_ct_sel = 1'b0;

        // Operations for internal registers - stay in idle state
        if (module_select & shift_dr_i) out_reg_shift_en = 1'b1; // For module regs

        if (module_select & capture_dr_i) begin
          out_reg_data_sel = 1'b1;  // select internal register data
          out_reg_ld_en    = 1'b1;   // For module regs
        end

        if (module_select & module_cmd & update_dr_i) begin
          if (intreg_instruction) regsel_ld_en = 1'b1;  // For module regs
          if (intreg_write      ) intreg_ld_en = 1'b1;  // For module regs
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

      STATE_RBEGIN: 
        if(!word_count_zero) begin  // Start a biu read transaction
          biu_strobe = 1'b1;
          addr_sel   = 1'b1;
          addr_ct_en = 1'b1;
        end

      STATE_RREADY: ; // Just a wait state

      STATE_RSTATUS: begin
        tdo_output_sel = 2'h0;
        inhibit        = 1'b1; // in case of early termination

        if (module_next_state == STATE_RBURST) begin
          error_reg_en     = 1'b1; // Check the wb_error bit
          out_reg_data_sel = 1'b0; // select BIU data
          out_reg_ld_en    = 1'b1;
          bit_ct_rst       = 1'b1;
          word_ct_sel      = 1'b1;
          word_ct_en       = 1'b1;

          if (decremented_word_count != 0 && !word_count_zero) begin  // Start a biu read transaction
            biu_strobe = 1'b1;
            addr_sel   = 1'b1;
            addr_ct_en = 1'b1;
          end
        end
      end

      STATE_RBURST: begin
        tdo_output_sel   = 2'h1;
        out_reg_shift_en = 1'b1;
        bit_ct_en        = 1'b1;
        crc_en           = 1'b1;
        crc_in_sel       = 1'b0;  // read data in output shift register LSB (tdo)
        inhibit          = 1'b1;  // in case of early termination

        if (bit_count_max) begin
          error_reg_en     = 1'b1; // Check the wb_error bit
          out_reg_data_sel = 1'b0; // select BIU data
          out_reg_ld_en    = 1'b1;
          bit_ct_rst       = 1'b1;
          word_ct_sel      = 1'b1;
          word_ct_en       = 1'b1;

          if (decremented_word_count != 0 && !word_count_zero) begin  // Start a biu read transaction
            biu_strobe = 1'b1;
            addr_sel   = 1'b1;
            addr_ct_en = 1'b1;
          end
        end
      end

      STATE_RCRC: begin
        // Just shift out the data, don't bother counting, we don't move on until update_dr_i
        tdo_output_sel = 2'h3;
        crc_shift_en   = 1'b1;
        inhibit        = 1'b1;
      end

      STATE_WREADY: ; // Just a wait state

      STATE_WWAIT: begin
        tdo_output_sel = 2'h1;
        inhibit        = 1'b1;  // in case of early termination

        if (module_next_state == STATE_WBURST) begin
          biu_clr_err = 1'b1; // If error occurred on last transaction of last burst, biu_err is still set.  Clear it.
          bit_ct_en   = 1'b1;
          word_ct_sel = 1'b1; // Pre-decrement the byte count
          word_ct_en  = 1'b1;
          crc_en      = 1'b1; // CRC gets dbg_tdi, which is 1 cycle ahead of data_register_i, so we need the bit there now in the CRC
          crc_in_sel  = 1'b1; // read data from dbg_tdi
        end
      end

      STATE_WBURST: begin
        bit_ct_en      = 1'b1;
        tdo_output_sel = 2'h1;
        crc_en         = 1'b1;
        crc_in_sel     = 1'b1;   // read data from tdi_i
        inhibit        = 1'b1;   // in case of early termination

        if (bit_count_max) begin
          error_reg_en = 1'b1; // Check the wb_error bit
          bit_ct_rst   = 1'b1; // Zero the bit count

          // start transaction. Can't do this here if not hispeed, biu_rdy
          // is the status bit, and it's 0 if we start a transaction here.
          biu_strobe   = 1'b1; // Start a BIU transaction
          addr_ct_en   = 1'b1; // Increment thte address counter

          // Also can't dec the byte count yet unless hispeed,
          // that would skip the last word.
          word_ct_sel  = 1'b1; // Decrement the byte count
          word_ct_en   = 1'b1;
        end
      end

      STATE_WSTATUS: begin
        tdo_output_sel = 2'h0; // Send the status bit to TDO
        error_reg_en   = 1'b1; // Check the wb_error bit

        // start transaction
        biu_strobe     = 1'b1; // Start a BIU transaction
        word_ct_sel    = 1'b1; // Decrement the byte count
        word_ct_en     = 1'b1;
        bit_ct_rst     = 1'b1; // Zero the bit count
        addr_ct_en     = 1'b1; // Increment thte address counter
        inhibit        = 1'b1; // in case of early termination
      end

      STATE_WCRC: begin
        bit_ct_en = 1'b1;
        inhibit   = 1'b1;    // in case of early termination
        if (module_next_state == STATE_WMATCH) tdo_output_sel = 2'h2;  // This is when the 'match' bit is actually read
      end

      STATE_WMATCH: begin
        tdo_output_sel = 2'h2;
        inhibit        = 1'b1;

        // Bit of a hack here...an error on the final write won't be detected in STATE_WSTATUS like the rest, 
        // so we assume the bus transaction is done and check it / latch it into the error register here.
        if (module_next_state == STATE_IDLE) error_reg_en = 1'b1;
      end

      default: ;
    endcase
  end
endmodule
