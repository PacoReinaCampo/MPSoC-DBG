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
//              MSP430 CPU                                                    //
//              Processing Unit                                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2015-2016 by the author(s)
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the authors nor the names of its contributors
//       may be used to endorse or promote products derived from this software
//       without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
// OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
// THE POSSIBILITY OF SUCH DAMAGE
//
////////////////////////////////////////////////////////////////////////////////
// Author(s):
//   Olivier Girard <olgirard@gmail.com>
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

`ifdef OMSP_NO_INCLUDE
`else
`include "peripheral_dbg_pu_msp430_defines.sv"
`endif

module peripheral_dbg_pu_msp430_i2c (
  // OUTPUTs
  output reg [ 5:0] dbg_addr,         // Debug register address
  output     [15:0] dbg_din,          // Debug register data input
  output reg        dbg_i2c_sda_out,  // Debug interface: I2C SDA OUT
  output reg        dbg_rd,           // Debug register data read
  output reg        dbg_wr,           // Debug register data write

  // INPUTs
  input        dbg_clk,            // Debug unit clock
  input [15:0] dbg_dout,           // Debug register data output
  input [ 6:0] dbg_i2c_addr,       // Debug interface: I2C ADDRESS
  input [ 6:0] dbg_i2c_broadcast,  // Debug interface: I2C Broadcast Address (for multicore systems)
  input        dbg_i2c_scl,        // Debug interface: I2C SCL
  input        dbg_i2c_sda_in,     // Debug interface: I2C SDA IN
  input        dbg_rd_rdy,         // Debug register data is ready for read
  input        dbg_rst,            // Debug unit reset
  input        mem_burst,          // Burst on going
  input        mem_burst_end,      // End TX/RX burst
  input        mem_burst_rd,       // Start TX burst
  input        mem_burst_wr,       // Start RX burst
  input        mem_bw              // Burst byte width
);

  //////////////////////////////////////////////////////////////////////////////
  // 1) I2C RECEIVE LINE SYNCHRONIZTION & FILTERING
  //////////////////////////////////////////////////////////////////////////////

  // Synchronize SCL/SDA inputs

  reg [1:0] data_sync_scl;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      data_sync_scl <= 2'b00;
    end else begin
      data_sync_scl <= {data_sync_scl[0], ~dbg_i2c_scl};
    end
  end

  wire scl_sync_n = data_sync_scl[1];

  wire scl_sync = ~scl_sync_n;

  reg [1:0] data_sync_sda_in;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      data_sync_sda_in <= 2'b00;
    end else begin
      data_sync_sda_in <= {data_sync_sda_in[0], ~dbg_i2c_sda_in};
    end
  end

  wire sda_in_sync_n = data_sync_sda_in[1];

  wire sda_in_sync = ~sda_in_sync_n;

  // SCL/SDA input buffers

  reg  [1:0] scl_buf;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      scl_buf <= 2'h3;
    end else begin
      scl_buf <= {scl_buf[0], scl_sync};
    end
  end

  reg [1:0] sda_in_buf;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      sda_in_buf <= 2'h3;
    end else begin
      sda_in_buf <= {sda_in_buf[0], sda_in_sync};
    end
  end

  // SCL/SDA Majority decision

  wire scl = (scl_sync & scl_buf[0]) | (scl_sync & scl_buf[1]) | (scl_buf[0] & scl_buf[1]);

  wire sda_in = (sda_in_sync & sda_in_buf[0]) | (sda_in_sync & sda_in_buf[1]) | (sda_in_buf[0] & sda_in_buf[1]);

  // SCL/SDA Edge detection

  // SDA Edge detection
  reg  sda_in_dly;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      sda_in_dly <= 1'b1;
    end else begin
      sda_in_dly <= sda_in;
    end
  end

  wire sda_in_fe = sda_in_dly & ~sda_in;
  wire sda_in_re = ~sda_in_dly & sda_in;
  wire sda_in_edge = sda_in_dly ^ sda_in;

  // SCL Edge detection
  reg  scl_dly;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      scl_dly <= 1'b1;
    end else begin
      scl_dly <= scl;
    end
  end

  wire       scl_fe = scl_dly & ~scl;
  wire       scl_re = ~scl_dly & scl;
  wire       scl_edge = scl_dly ^ scl;

  // Delayed SCL Rising-Edge for SDA data sampling
  reg  [1:0] scl_re_dly;
  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      scl_re_dly <= 2'b00;
    end else begin
      scl_re_dly <= {scl_re_dly[0], scl_re};
    end
  end

  wire scl_sample = scl_re_dly[1];

  //////////////////////////////////////////////////////////////////////////////
  // 2) I2C START & STOP CONDITION DETECTION
  //////////////////////////////////////////////////////////////////////////////

  // Start condition

  wire start_detect = sda_in_fe & scl;

  // Stop condition

  wire stop_detect = sda_in_re & scl;

  // I2C Slave Active
  // The I2C logic will be activated whenever a start condition
  // is detected and will be disactivated if the slave address
  // doesn't match or if a stop condition is detected.

  wire i2c_addr_not_valid;

  reg  i2c_active_seq;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      i2c_active_seq <= 1'b0;
    end else if (start_detect) begin
      i2c_active_seq <= 1'b1;
    end else if (stop_detect || i2c_addr_not_valid) begin
      i2c_active_seq <= 1'b0;
    end
  end

  wire       i2c_active = i2c_active_seq & ~stop_detect;
  wire       i2c_init = ~i2c_active | start_detect;

  //////////////////////////////////////////////////////////////////////////////
  // 3) I2C STATE MACHINE
  //////////////////////////////////////////////////////////////////////////////

  // State register/wires
  reg  [2:0] i2c_state;
  reg  [2:0] i2c_state_nxt;

  // Utility signals
  reg  [8:0] shift_buf;
  wire       shift_rx_done;
  wire       shift_tx_done;

  // State machine definition
  parameter RX_ADDR = 3'h0;
  parameter RX_ADDR_ACK = 3'h1;
  parameter RX_DATA = 3'h2;
  parameter RX_DATA_ACK = 3'h3;
  parameter TX_DATA = 3'h4;
  parameter TX_DATA_ACK = 3'h5;

  // State transition
  always @(i2c_state or i2c_init or shift_rx_done or i2c_addr_not_valid or shift_tx_done or scl_fe or shift_buf or sda_in) begin
    case (i2c_state)
      RX_ADDR: begin
        i2c_state_nxt = i2c_init ? RX_ADDR : ~shift_rx_done ? RX_ADDR : i2c_addr_not_valid ? RX_ADDR : RX_ADDR_ACK;
      end
      RX_ADDR_ACK: begin
        i2c_state_nxt = i2c_init ? RX_ADDR : ~scl_fe ? RX_ADDR_ACK : shift_buf[0] ? TX_DATA : RX_DATA;
      end
      RX_DATA: begin
        i2c_state_nxt = i2c_init ? RX_ADDR : ~shift_rx_done ? RX_DATA : RX_DATA_ACK;
      end
      RX_DATA_ACK: begin
        i2c_state_nxt = i2c_init ? RX_ADDR : ~scl_fe ? RX_DATA_ACK : RX_DATA;
      end
      TX_DATA: begin
        i2c_state_nxt = i2c_init ? RX_ADDR : ~shift_tx_done ? TX_DATA : TX_DATA_ACK;
      end
      TX_DATA_ACK: begin
        i2c_state_nxt = i2c_init ? RX_ADDR : ~scl_fe ? TX_DATA_ACK : ~sda_in ? TX_DATA : RX_ADDR;
      end
      // pragma coverage off
      default: begin
        i2c_state_nxt = RX_ADDR;
      end
      // pragma coverage on
    endcase
  end

  // State machine
  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      i2c_state <= RX_ADDR;
    end else begin
      i2c_state <= i2c_state_nxt;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // 4) I2C SHIFT REGISTER (FOR RECEIVING & TRANSMITING)
  //////////////////////////////////////////////////////////////////////////////

  wire shift_rx_en = ((i2c_state == RX_ADDR) | (i2c_state == RX_DATA) | (i2c_state == RX_DATA_ACK));
  wire shift_tx_en = (i2c_state == TX_DATA) | (i2c_state == TX_DATA_ACK);
  wire shift_tx_en_pre = (i2c_state_nxt == TX_DATA) | (i2c_state_nxt == TX_DATA_ACK);

  assign shift_rx_done = shift_rx_en & scl_fe & shift_buf[8];
  assign shift_tx_done = shift_tx_en & scl_fe & (shift_buf == 9'h100);

  wire shift_buf_rx_init = i2c_init | ((i2c_state == RX_ADDR_ACK) & scl_fe & ~shift_buf[0]) | ((i2c_state == RX_DATA_ACK) & scl_fe);
  wire shift_buf_rx_en = shift_rx_en & scl_sample;

  wire shift_buf_tx_init = ((i2c_state == RX_ADDR_ACK) & scl_re & shift_buf[0]) | ((i2c_state == TX_DATA_ACK) & scl_re);
  wire shift_buf_tx_en = shift_tx_en_pre & scl_fe & (shift_buf != 9'h100);

  wire [7:0] shift_tx_val;

  wire [8:0] shift_buf_nxt = shift_buf_rx_init ? 9'h001 :  // RX Init
  shift_buf_tx_init ? {shift_tx_val, 1'b1} :  // TX Init
  shift_buf_rx_en ? {shift_buf[7:0], sda_in} :  // RX Shift
  shift_buf_tx_en ? {shift_buf[7:0], 1'b0} :  // TX Shift
  shift_buf[8:0];  // Hold

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      shift_buf <= 9'h001;
    end else begin
      shift_buf <= shift_buf_nxt;
    end
  end

  // Detect when the received I2C device address is not valid
`ifdef DBG_I2C_BROADCAST
  assign i2c_addr_not_valid = (i2c_state == RX_ADDR) && shift_rx_done && ((shift_buf[7:1] != dbg_i2c_broadcast[6:0]) && (shift_buf[7:1] != dbg_i2c_addr[6:0]));
`else
  assign i2c_addr_not_valid = (i2c_state == RX_ADDR) && shift_rx_done && (shift_buf[7:1] != dbg_i2c_addr[6:0]);
`endif

  // Utility signals
  wire shift_rx_data_done = shift_rx_done & (i2c_state == RX_DATA);
  wire shift_tx_data_done = shift_tx_done;

  //////////////////////////////////////////////////////////////////////////////
  // 5) I2C TRANSMIT BUFFER
  //////////////////////////////////////////////////////////////////////////////

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      dbg_i2c_sda_out <= 1'b1;
    end else if (scl_fe) begin
      dbg_i2c_sda_out <= ~((i2c_state_nxt == RX_ADDR_ACK) || (i2c_state_nxt == RX_DATA_ACK) || (shift_buf_tx_en & ~shift_buf[8]));
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // 6) DEBUG INTERFACE STATE MACHINE
  //////////////////////////////////////////////////////////////////////////////

  // State register/wires
  reg [2:0] dbg_state;
  reg [2:0] dbg_state_nxt;

  // Utility signals
  reg       dbg_bw;

  // State machine definition
  parameter RX_CMD = 3'h0;
  parameter RX_BYTE_LO = 3'h1;
  parameter RX_BYTE_HI = 3'h2;
  parameter TX_BYTE_LO = 3'h3;
  parameter TX_BYTE_HI = 3'h4;

  // State transition
  always @(dbg_state or shift_rx_data_done or shift_tx_data_done or shift_buf or dbg_bw or mem_burst_wr or mem_burst_rd or mem_burst or mem_burst_end or mem_bw) begin
    case (dbg_state)
      RX_CMD: begin
        dbg_state_nxt = mem_burst_wr ? RX_BYTE_LO : mem_burst_rd ? TX_BYTE_LO : ~shift_rx_data_done ? RX_CMD : shift_buf[7] ? RX_BYTE_LO : TX_BYTE_LO;
      end
      RX_BYTE_LO: begin
        dbg_state_nxt = (mem_burst & mem_burst_end) ? RX_CMD : ~shift_rx_data_done ? RX_BYTE_LO : (mem_burst & ~mem_burst_end) ? (mem_bw ? RX_BYTE_LO : RX_BYTE_HI) : dbg_bw ? RX_CMD : RX_BYTE_HI;
      end
      RX_BYTE_HI: begin
        dbg_state_nxt = ~shift_rx_data_done ? RX_BYTE_HI : (mem_burst & ~mem_burst_end) ? RX_BYTE_LO : RX_CMD;
      end
      TX_BYTE_LO: begin
        dbg_state_nxt = ~shift_tx_data_done ? TX_BYTE_LO : (mem_burst & mem_bw) ? TX_BYTE_LO : (mem_burst & ~mem_bw) ? TX_BYTE_HI : ~dbg_bw ? TX_BYTE_HI : RX_CMD;
      end
      TX_BYTE_HI: begin
        dbg_state_nxt = ~shift_tx_data_done ? TX_BYTE_HI : mem_burst ? TX_BYTE_LO : RX_CMD;
      end
      // pragma coverage off
      default: begin
        dbg_state_nxt = RX_CMD;
      end
      // pragma coverage on
    endcase
  end

  // State machine
  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      dbg_state <= RX_CMD;
    end else begin
      dbg_state <= dbg_state_nxt;
    end
  end

  // Utility signals
  wire cmd_valid = (dbg_state == RX_CMD) & shift_rx_data_done;
  wire rx_lo_valid = (dbg_state == RX_BYTE_LO) & shift_rx_data_done;
  wire rx_hi_valid = (dbg_state == RX_BYTE_HI) & shift_rx_data_done;

  //////////////////////////////////////////////////////////////////////////////
  // 7) REGISTER READ/WRITE ACCESS
  //////////////////////////////////////////////////////////////////////////////

  parameter MEM_DATA = 6'h06;

  // Debug register address & bit width
  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      dbg_bw   <= 1'b0;
      dbg_addr <= 6'h00;
    end else if (cmd_valid) begin
      dbg_bw   <= shift_buf[6];
      dbg_addr <= shift_buf[5:0];
    end else if (mem_burst) begin
      dbg_bw   <= mem_bw;
      dbg_addr <= MEM_DATA;
    end
  end

  // Debug register data input
  reg [7:0] dbg_din_lo;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      dbg_din_lo <= 8'h00;
    end else if (rx_lo_valid) begin
      dbg_din_lo <= shift_buf[7:0];
    end
  end

  reg [7:0] dbg_din_hi;

  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      dbg_din_hi <= 8'h00;
    end else if (rx_lo_valid) begin
      dbg_din_hi <= 8'h00;
    end else if (rx_hi_valid) begin
      dbg_din_hi <= shift_buf[7:0];
    end
  end

  assign dbg_din = {dbg_din_hi, dbg_din_lo};

  // Debug register data write command
  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      dbg_wr <= 1'b0;
    end else begin
      dbg_wr <= (mem_burst & mem_bw) ? rx_lo_valid : (mem_burst & ~mem_bw) ? rx_hi_valid : dbg_bw ? rx_lo_valid : rx_hi_valid;
    end
  end

  // Debug register data read command
  always @(posedge dbg_clk or posedge dbg_rst) begin
    if (dbg_rst) begin
      dbg_rd <= 1'b0;
    end else begin
      dbg_rd <= (mem_burst & mem_bw) ? (shift_tx_data_done & (dbg_state == TX_BYTE_LO)) : (mem_burst & ~mem_bw) ? (shift_tx_data_done & (dbg_state == TX_BYTE_HI)) : cmd_valid ? ~shift_buf[7] : 1'b0;
    end
  end

  // Debug register data read value
  assign shift_tx_val = (dbg_state == TX_BYTE_HI) ? dbg_dout[15:8] : dbg_dout[7:0];
endmodule

`ifdef OMSP_NO_INCLUDE
`else
`include "peripheral_dbg_pu_msp430_undefines.sv"
`endif
