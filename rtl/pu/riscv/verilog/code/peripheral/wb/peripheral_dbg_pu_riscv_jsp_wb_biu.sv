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

// Top module
module peripheral_dbg_pu_riscv_jsp_wb_tl (
  // Debug interface signals
  input        tck_i,
  input        rst_i,
  input  [7:0] data_i,
  output [7:0] data_o,
  output [3:0] bytes_available_o,
  output [3:0] bytes_free_o,
  input        rd_strobe_i,
  input        wr_strobe_i,

  // Wishbone signals
  input            wb_clk_i,
  input            wb_rst_i,
  input            wb_cyc_i,
  input            wb_stb_i,
  input            wb_we_i,
  input      [2:0] wb_adr_i,
  input      [7:0] wb_dat_i,
  output reg [7:0] wb_dat_o,
  output           wb_ack_o,
  output           wb_err_o,

  output int_o
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  localparam RD_IDLE = 2'b11;
  localparam RD_PUSH = 2'b10;
  localparam RD_POP = 2'b01;
  localparam RD_LATCH = 2'b00;

  localparam WR_IDLE = 2'b10;
  localparam WR_PUSH = 2'b01;
  localparam WR_POP = 2'b00;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // Registers
  reg  [7:0] data_in;
  reg  [7:0] rdata;
  reg        wen_tff;
  reg        ren_tff;

  // Wires  
  wire       fifo_ack;
  wire [3:0] wr_bytes_free;
  wire [3:0] rd_bytes_avail;
  wire [3:0] wr_bytes_avail;  // used to generate wr_fifo_not_empty
  wire       rd_bytes_avail_not_zero;
  wire       ren_sff_out;
  wire [7:0] rd_fifo_data_out;
  wire [7:0] data_to_extbus;
  wire [7:0] data_from_extbus;
  wire       wr_fifo_not_empty;  // this is for the WishBone interface LSR register
  wire       rx_fifo_rst;  // rcvr in the WB sense, opposite most of the rest of this file
  wire       tx_fifo_rst;  // ditto

  // Control Signals (FSM outputs)
  reg        wda_rst;  // reset wdata_avail SFF
  reg        wpp;  // Write FIFO PUSH (1) or POP (0)
  reg        w_fifo_en;  // Enable write FIFO
  reg        ren_rst;  // reset 'pop' SFF
  reg        rdata_en;  // enable 'rdata' register
  reg        rpp;  // read FIFO PUSH (1) or POP (0)
  reg        r_fifo_en;  // enable read FIFO    
  reg        r_wb_ack;  // read FSM acks WB transaction
  reg        w_wb_ack;  // write FSM acks WB transaction

  // Indicators to FSMs
  wire       wdata_avail;  // JTAG side has data available
  wire       fifo_rd;  // ext.bus requests read
  wire       fifo_wr;  // ext.bus requests write
  wire       pop;  // JTAG side received a byte, pop and get next
  wire       rcz;  // zero bytes available in read FIFO

  logic [1:0] rd_fsm_state, next_rd_fsm_state;
  logic [1:0] wr_fsm_state, next_wr_fsm_state;

  // Interface hardware & 16550 registers
  // Interface signals to read and write fifos:
  // fifo_rd : read strobe
  // fifo_wr : write strobe
  // fifo_ack: fifo has completed operation

  // 16550 registers
  logic [3:0] ier;
  logic [7:0] iir;
  // logic [5:0] fcr;
  logic [7:0] lcr;
  logic [4:0] mcr;
  logic [7:0] lsr;
  logic [7:0] msr;
  logic [7:0] scr;

  wire        reg_ack;
  wire        rd_fifo_not_full;  // "rd fifo" is the one the WB writes to
  wire        rd_fifo_becoming_empty;
  reg         thr_int_arm;  // used so that an IIR read can clear a transmit interrupt
  wire        iir_read;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  // TCK clock domain
  // There is no FSM here, just signal latching and clock
  // domain synchronization

  assign data_o = rdata;

  // Write enable (WEN) toggle FF
  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      wen_tff <= 'b0;
    end else if (wr_strobe_i) begin
      wen_tff <= ~wen_tff;
    end
  end

  // Read enable (REN) toggle FF
  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      ren_tff <= 'b0;
    end else if (rd_strobe_i) begin
      ren_tff <= ~ren_tff;
    end
  end

  // Write data register
  always @(posedge tck_i, posedge rst_i) begin
    if (rst_i) begin
      data_in <= 'h0;
    end else if (wr_strobe_i) begin
      data_in <= data_i;
    end
  end

  // Wishbone clock domain

  // Combinatorial assignments
  assign rd_bytes_avail_not_zero = |rd_bytes_avail;
  assign pop                     = ren_sff_out & rd_bytes_avail_not_zero;
  assign rcz                     = ~rd_bytes_avail_not_zero;
  assign fifo_ack                = r_wb_ack | w_wb_ack;
  assign wr_fifo_not_empty       = |wr_bytes_avail;

  // rdata register
  always @(posedge wb_clk_i, posedge rst_i) begin
    if (rst_i) begin
      rdata <= 8'h0;
    end else if (rdata_en) begin
      rdata <= rd_fifo_data_out;
    end
  end

  // WEN SFF
  peripheral_dbg_pu_riscv_syncflop wen_sff (
    .RESET    (rst_i),
    .DEST_CLK (wb_clk_i),
    .D_SET    (1'b0),
    .D_RST    (wda_rst),
    .TOGGLE_IN(wen_tff),
    .D_OUT    (wdata_avail)
  );

  // REN SFF
  peripheral_dbg_pu_riscv_syncflop ren_sff (
    .RESET    (rst_i),
    .DEST_CLK (wb_clk_i),
    .D_SET    (1'b0),
    .D_RST    (ren_rst),
    .TOGGLE_IN(ren_tff),
    .D_OUT    (ren_sff_out)
  );

  // TO-DO: syncreg.RST should be synchronised to DFF clock domain
  // 'free space available' syncreg
  peripheral_dbg_pu_riscv_syncreg freespace_syncreg (
    .RST     (rst_i),
    .CLKA    (wb_clk_i),
    .CLKB    (tck_i),
    .DATA_IN (wr_bytes_free),
    .DATA_OUT(bytes_free_o)
  );

  // 'bytes available' syncreg
  peripheral_dbg_pu_riscv_syncreg bytesavail_syncreg (
    .RST     (rst_i),
    .CLKA    (wb_clk_i),
    .CLKB    (tck_i),
    .DATA_IN (rd_bytes_avail),
    .DATA_OUT(bytes_available_o)
  );

  // TO-DO: synch. FIFO resets
  // write FIFO
  peripheral_dbg_pu_riscv_bytefifo wr_fifo (
    .RST        (rst_i | rx_fifo_rst),  // rst_i from JTAG clk domain, rx_fifo_rst from WB, RST is async reset
    .CLK        (wb_clk_i),
    .DATA_IN    (data_in),
    .DATA_OUT   (data_to_extbus),
    .PUSH_POPn  (wpp),
    .EN         (w_fifo_en),
    .BYTES_AVAIL(wr_bytes_avail),
    .BYTES_FREE (wr_bytes_free)
  );

  // read FIFO
  peripheral_dbg_pu_riscv_bytefifo rd_fifo (
    .RST        (rst_i | tx_fifo_rst),  // rst_i from JTAG clk domain, tx_fifo_rst from WB, RST is async reset
    .CLK        (wb_clk_i),
    .DATA_IN    (data_from_extbus),
    .DATA_OUT   (rd_fifo_data_out),
    .PUSH_POPn  (rpp),
    .EN         (r_fifo_en),
    .BYTES_AVAIL(rd_bytes_avail),
    .BYTES_FREE ()
  );

  // State machine for the read FIFO

  // Sequential bit
  always @(posedge wb_clk_i, posedge rst_i) begin
    if (rst_i) begin
      rd_fsm_state <= RD_IDLE;
    end else begin
      rd_fsm_state <= next_rd_fsm_state;
    end
  end

  // Determination of next state (combinatorial)
  always @(*) begin
    case (rd_fsm_state)
      RD_IDLE: begin
        if (fifo_wr) begin
          next_rd_fsm_state = RD_PUSH;
        end else if (pop) begin
          next_rd_fsm_state = RD_POP;
        end else begin
          next_rd_fsm_state = RD_IDLE;
        end
      end
      RD_PUSH: begin
        if (rcz) begin
          next_rd_fsm_state = RD_LATCH;  // putting first item in fifo, move to rdata in state LATCH
        end else if (pop) begin
          next_rd_fsm_state = RD_POP;
        end else begin
          next_rd_fsm_state = RD_IDLE;
        end
      end
      RD_POP: begin
        next_rd_fsm_state = RD_LATCH;  // new data at FIFO head, move to rdata in state LATCH
      end
      RD_LATCH: begin
        if (fifo_wr) begin
          next_rd_fsm_state = RD_PUSH;
        end else if (pop) begin
          next_rd_fsm_state = RD_POP;
        end else begin
          next_rd_fsm_state = RD_IDLE;
        end
      end
      default: begin
        next_rd_fsm_state = RD_IDLE;
      end
    endcase
  end

  // Outputs of state machine (combinatorial)
  always @(*) begin
    ren_rst   = 1'b0;
    rpp       = 1'b0;
    r_fifo_en = 1'b0;
    rdata_en  = 1'b0;
    r_wb_ack  = 1'b0;

    case (rd_fsm_state)
      RD_PUSH: begin
        rpp       = 1'b1;
        r_fifo_en = 1'b1;
        r_wb_ack  = 1'b1;
      end

      RD_POP: begin
        ren_rst   = 1'b1;
        r_fifo_en = 1'b1;
      end

      RD_LATCH: begin
        rdata_en = 1'b1;
      end

      default: begin
      end
    endcase
  end

  // State machine for the write FIFO

  // Sequential bit
  always @(posedge wb_clk_i, posedge rst_i) begin
    if (rst_i) begin
      wr_fsm_state <= WR_IDLE;
    end else begin
      wr_fsm_state <= next_wr_fsm_state;
    end
  end

  // Determination of next state (combinatorial)
  always @(*) begin
    case (wr_fsm_state)
      WR_IDLE: begin
        if (fifo_rd) begin
          next_wr_fsm_state = WR_POP;
        end else if (wdata_avail) begin
          next_wr_fsm_state = WR_PUSH;
        end else begin
          next_wr_fsm_state = WR_IDLE;
        end
      end
      WR_PUSH: begin
        if (fifo_rd) begin
          next_wr_fsm_state = WR_POP;
        end else begin
          next_wr_fsm_state = WR_IDLE;
        end
      end
      WR_POP: begin
        if (wdata_avail) begin
          next_wr_fsm_state = WR_PUSH;
        end else begin
          next_wr_fsm_state = WR_IDLE;
        end
      end
      default: next_wr_fsm_state = WR_IDLE;
    endcase
  end

  // Outputs of state machine (combinatorial)
  always @(*) begin
    wda_rst   = 1'b0;
    wpp       = 1'b0;
    w_fifo_en = 1'b0;
    w_wb_ack  = 1'b0;

    case (wr_fsm_state)
      WR_PUSH: begin
        wda_rst   = 1'b1;
        wpp       = 1'b1;
        w_fifo_en = 1'b1;
      end

      WR_POP: begin
        w_wb_ack  = 1'b1;
        w_fifo_en = 1'b1;
      end

      default: begin
      end
    endcase
  end

  // These 16550 registers are not implemented
  assign mcr              = 'h0;
  assign msr              = 'hb;

  // Create the simple / combinatorial registers
  assign rd_fifo_not_full = !(rd_bytes_avail == 4'h8);
  assign lsr              = {1'b0, rd_fifo_not_full, rd_fifo_not_full, 4'h0, wr_fifo_not_empty};

  // Create writeable registers
  always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
      ier <= 'h0;
      lcr <= 'h0;
      scr <= 'h0;
    end else if (wb_cyc_i & wb_stb_i & wb_we_i) begin
      case (wb_adr_i)
        3'b001: begin
          if (!lcr[7]) begin
            ier <= wb_dat_i[3:0];
          end
        end
        3'b011: begin
          lcr <= wb_dat_i;
        end
        3'b111: begin
          scr <= wb_dat_i;
        end
      endcase
    end
  end

  // Create handshake signals to/from the FIFOs
  assign fifo_rd                = wb_cyc_i & wb_stb_i & ~wb_we_i & (wb_adr_i == 3'b000) & ~lcr[7];
  assign fifo_wr                = wb_cyc_i & wb_stb_i & wb_we_i & (wb_adr_i == 3'b000) & ~lcr[7];

  // Wishbone responses
  assign wb_ack_o               = fifo_ack | reg_ack;
  assign wb_err_o               = 1'b0;

  // acknowledge all accesses, except to FIFOs
  assign reg_ack                = wb_cyc_i & wb_stb_i & (lcr[7] | wb_adr_i != 3'b000);

  // Create FIFO reset signals
  assign rx_fifo_rst            = wb_cyc_i & wb_stb_i & wb_we_i & (wb_adr_i == 3'b010) & wb_dat_i[1];
  assign tx_fifo_rst            = wb_cyc_i & wb_stb_i & wb_we_i & (wb_adr_i == 3'b010) & wb_dat_i[2];

  // Create IIR (and THR INT arm bit)
  assign rd_fifo_becoming_empty = r_fifo_en & (~rpp) & (rd_bytes_avail == 4'h1);  // "rd fifo" is the ext.bus write FIFO...

  assign iir_read               = wb_cyc_i & wb_stb_i & ~wb_we_i & (wb_adr_i == 3'b010);

  always @(posedge wb_clk_i) begin
    if (wb_rst_i) begin
      thr_int_arm <= 1'b0;
    end else if (fifo_wr || rd_fifo_becoming_empty) begin
      thr_int_arm <= 1'b1;  // Set when WB write fifo becomes empty, or on a write to it
    end else if (iir_read && !wr_fifo_not_empty) begin
      thr_int_arm <= 1'b0;
    end
  end

  always @(*) begin
    if (wr_fifo_not_empty) begin
      iir = 'b100;
    end else if (thr_int_arm && rd_fifo_not_full) begin
      iir = 'b010;
    end else begin
      iir = 'b001;
    end
  end

  // Create ext.bus Data Out
  always @(*) begin
    case (wb_adr_i)
      3'b000:  wb_dat_o = data_to_extbus;
      3'b001:  wb_dat_o = {4'h0, ier};
      3'b010:  wb_dat_o = iir;
      3'b011:  wb_dat_o = lcr;
      3'b100:  wb_dat_o = mcr;
      3'b101:  wb_dat_o = lsr;
      3'b110:  wb_dat_o = msr;
      3'b111:  wb_dat_o = scr;
      default: wb_dat_o = 'h0;
    endcase
  end

  assign data_from_extbus = wb_dat_i;  // Data to the FIFO

  // Generate interrupt output
  assign int_o            = (rd_fifo_not_full & thr_int_arm & ier[1]) | (wr_fifo_not_empty & ier[0]);
endmodule
