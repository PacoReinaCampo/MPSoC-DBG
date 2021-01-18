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

module adbg_jsp_biu (
  // Debug interface signals
  input        tck_i,
  input        rst_i,
  input  [7:0] data_i,  // Assume short words are in UPPER order bits!
  output [7:0] data_o,
  output [3:0] bytes_free_o,
  output [3:0] bytes_available_o,
  input        rd_strobe_i,
  input        wr_strobe_i,

  input debug_select_i,

  // Wishbone signals
  input         wb_clk_i,
  input         wb_rst_i,
  input  [31:0] wb_adr_i,
  output [31:0] wb_dat_o,
  input  [31:0] wb_dat_i,
  input         wb_cyc_i,
  input         wb_stb_i,
  input  [ 3:0] wb_sel_i,
  input         wb_we_i,
  output        wb_ack_o,
  input         wb_cab_i,
  output        wb_err_o,
  input  [ 2:0] wb_cti_i,
  input  [ 1:0] wb_bte_i,
  output        int_o
);

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  `define STATE_WR_IDLE     2'h0
  `define STATE_WR_PUSH     2'h1
  `define STATE_WR_POP      2'h2

  `define STATE_RD_IDLE     2'h0
  `define STATE_RD_PUSH     2'h1
  `define STATE_RD_POP      2'h2
  `define STATE_RD_LATCH    2'h3

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // Registers
  reg [7:0]   data_in;
  reg [7:0]   rdata;
  reg         wen_tff;
  reg         ren_tff;

  // Wires  
  wire         wb_fifo_ack;
  wire [3:0]   wr_bytes_free;
  wire [3:0]   rd_bytes_avail;
  wire [3:0]   wr_bytes_avail;  // used to generate wr_fifo_not_empty
  wire         rd_bytes_avail_not_zero;
  wire         ren_sff_out;   
  wire [7:0]   rd_fifo_data_out;
  wire [7:0]   data_to_wb;
  wire [7:0]   data_from_wb;
  wire         wr_fifo_not_empty;  // this is for the WishBone interface LSR register
  wire         rcvr_fifo_rst;  // rcvr in the WB sense, opposite most of the rest of this file
  wire         xmit_fifo_rst;  // ditto

  // Control Signals (FSM outputs)
  reg    wda_rst;   // reset wdata_avail SFF
  reg    wpp;       // Write FIFO PUSH (1) or POP (0)
  reg    w_fifo_en; // Enable write FIFO
  reg    ren_rst;   // reset 'pop' SFF
  reg    rdata_en;  // enable 'rdata' register
  reg    rpp;       // read FIFO PUSH (1) or POP (0)
  reg    r_fifo_en; // enable read FIFO    
  reg    r_wb_ack;  // read FSM acks WB transaction
  reg    w_wb_ack;  // write FSM acks WB transaction

  // Indicators to FSMs
  wire   wdata_avail; // JTAG side has data available
  wire   wb_rd;       // WishBone requests read
  wire   wb_wr;       // WishBone requests write
  wire   pop;         // JTAG side received a byte, pop and get next
  wire   rcz;         // zero bytes available in read FIFO

  // State machine for the read FIFO

  reg [1:0] rd_fsm_state;
  reg [1:0] next_rd_fsm_state;

  // WishBone interface hardware
  // Interface signals to read and write fifos:
  // wb_rd:  read strobe
  // wb_wr:  write strobe
  // wb_fifo_ack: fifo has completed operation

  wire [31:0] bus_data_lo;
  wire [31:0] bus_data_hi;
  wire        wb_reg_ack;
  wire        rd_fifo_not_full;  // "rd fifo" is the one the WB writes to
  reg  [2:0]  iir_gen;  // actually combinatorial
  wire        rd_fifo_becoming_empty;

  // These 16550 registers are at least partly implemented
  reg         reg_dlab_bit;  // part of the LCR
  reg [3:0]   reg_ier;
  wire [2:0]  reg_iir;
  reg         thr_int_arm;  // used so that an IIR read can clear a transmit interrupt
  wire [7:0]  reg_lsr;
  wire        reg_dlab_bit_wren;
  wire        reg_ier_wren;
  wire        reg_iir_rden;
  wire [7:0]  reg_lcr;  // the DLAB bit above is the 8th bit
  wire        reg_fcr_wren;  // FCR is WR-only, at the same address as the IIR (contains SW reset bits)

  // These 16550 registers are not implemented here
  wire [7:0]  reg_mcr;
  wire [7:0]  reg_msr;
  wire [7:0]  reg_scr;
  wire        fifo_access;

  // State machine for the write FIFO
  reg [1:0] wr_fsm_state;
  reg [1:0] next_wr_fsm_state;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  // TCK clock domain
  // There is no FSM here, just signal latching and clock domain synchronization
  assign data_o = rdata;

  // Write enable (WEN) toggle FF
  always @ (posedge tck_i or posedge rst_i) begin
    if(rst_i) wen_tff <= 1'b0;
    else if(wr_strobe_i) wen_tff <= ~wen_tff;
  end 

  // Read enable (REN) toggle FF
  always @ (posedge tck_i or posedge rst_i) begin
    if(rst_i) ren_tff <= 1'b0;
    else if(rd_strobe_i) ren_tff <= ~ren_tff;
  end

  // Write data register
  always @ (posedge tck_i or posedge rst_i) begin
    if(rst_i) data_in <= 8'h0;
    else if(wr_strobe_i) data_in <= data_i;
  end

  // Wishbone clock domain

  // Combinatorial assignments
  assign rd_bytes_avail_not_zero = !(rd_bytes_avail == 4'h0);
  assign pop = (ren_sff_out | ~debug_select_i) & rd_bytes_avail_not_zero;
  assign rcz = ~rd_bytes_avail_not_zero;
  assign wb_fifo_ack = r_wb_ack | w_wb_ack;
  assign wr_fifo_not_empty = !(wr_bytes_avail == 4'h0);

  // rdata register
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) rdata <= 8'h0;
    else if(rdata_en) rdata <= rd_fifo_data_out;
  end

  // WEN SFF
  adbg_syncflop wen_sff (
    .DEST_CLK(wb_clk_i),
    .D_SET(1'b0),
    .D_RST(wda_rst),
    .RESET(rst_i),
    .TOGGLE_IN(wen_tff),
    .D_OUT(wdata_avail)
  );

  // REN SFF
  adbg_syncflop ren_sff (
    .DEST_CLK(wb_clk_i),
    .D_SET(1'b0),
    .D_RST(ren_rst),
    .RESET(rst_i),
    .TOGGLE_IN(ren_tff),
    .D_OUT(ren_sff_out)
  );

  // 'free space available' syncreg
  adbg_syncreg freespace_syncreg (
    .CLKA(wb_clk_i),
    .CLKB(tck_i),
    .RST(rst_i),
    .DATA_IN(wr_bytes_free),
    .DATA_OUT(bytes_free_o)
  );

  // 'bytes available' syncreg
  adbg_syncreg bytesavail_syncreg (
    .CLKA(wb_clk_i),
    .CLKB(tck_i),
    .RST(rst_i),
    .DATA_IN(rd_bytes_avail),
    .DATA_OUT(bytes_available_o)
  );

  // write FIFO
  adbg_bytefifo wr_fifo (
    .CLK(wb_clk_i),
    .RST(rst_i | rcvr_fifo_rst),  // rst_i from JTAG clk domain, rcvr_fifo_rst from WB, RST is async reset
    .DATA_IN(data_in),
    .DATA_OUT(data_to_wb),
    .PUSH_POPn(wpp),
    .EN(w_fifo_en),
    .BYTES_AVAIL(wr_bytes_avail),
    .BYTES_FREE(wr_bytes_free)
  );

  // read FIFO
  adbg_bytefifo rd_fifo (
    .CLK(wb_clk_i),
    .RST(rst_i | xmit_fifo_rst),  // rst_i from JTAG clk domain, xmit_fifo_rst from WB, RST is async reset
    .DATA_IN(data_from_wb),
    .DATA_OUT(rd_fifo_data_out),
    .PUSH_POPn(rpp),
    .EN(r_fifo_en),
    .BYTES_AVAIL(rd_bytes_avail),
    .BYTES_FREE()
  );

  // Sequential bit
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) rd_fsm_state <= `STATE_RD_IDLE;
    else rd_fsm_state <= next_rd_fsm_state; 
  end

  // Determination of next state (combinatorial)
  always @ (rd_fsm_state or wb_wr or pop or rcz) begin
    case (rd_fsm_state)
      `STATE_RD_IDLE : begin
        if(wb_wr) next_rd_fsm_state <= `STATE_RD_PUSH;
        else if (pop) next_rd_fsm_state <= `STATE_RD_POP;
        else next_rd_fsm_state <= `STATE_RD_IDLE;
      end
      `STATE_RD_PUSH : begin
        if(rcz) next_rd_fsm_state <= `STATE_RD_LATCH;  // putting first item in fifo, move to rdata in state LATCH
        else if(pop) next_rd_fsm_state <= `STATE_RD_POP;
        else next_rd_fsm_state <= `STATE_RD_IDLE;
      end
      `STATE_RD_POP : begin
        next_rd_fsm_state <= `STATE_RD_LATCH; // new data at FIFO head, move to rdata in state LATCH
      end
      `STATE_RD_LATCH : begin
        if(wb_wr) next_rd_fsm_state <= `STATE_RD_PUSH;
        else if(pop) next_rd_fsm_state <= `STATE_RD_POP;
        else next_rd_fsm_state <= `STATE_RD_IDLE;
      end
      default : begin
        next_rd_fsm_state <= `STATE_RD_IDLE;
      end
    endcase
  end

  // Outputs of state machine (combinatorial)
  always @ (rd_fsm_state) begin
    ren_rst <= 1'b0;
    rpp <= 1'b0;
    r_fifo_en <= 1'b0;
    rdata_en <= 1'b0;
    r_wb_ack <= 1'b0;

    case (rd_fsm_state)
      `STATE_RD_IDLE : ;
      `STATE_RD_PUSH : begin
        rpp <= 1'b1;
        r_fifo_en <= 1'b1;
        r_wb_ack <= 1'b1;
      end
      `STATE_RD_POP : begin
        ren_rst <= 1'b1;
        r_fifo_en <= 1'b1;
      end
      `STATE_RD_LATCH : begin
        rdata_en <= 1'b1;
      end
    endcase
  end

  // Sequential bit
  always @ (posedge wb_clk_i or posedge rst_i) begin
    if(rst_i) wr_fsm_state <= `STATE_WR_IDLE;
    else wr_fsm_state <= next_wr_fsm_state; 
  end

  // Determination of next state (combinatorial)
  always @ (wr_fsm_state or wb_rd or wdata_avail) begin
    case (wr_fsm_state)

      `STATE_WR_IDLE : begin
        if(wb_rd) next_wr_fsm_state <= `STATE_WR_POP;
        else if (wdata_avail) next_wr_fsm_state <= `STATE_WR_PUSH;
        else next_wr_fsm_state <= `STATE_WR_IDLE;
      end
      `STATE_WR_PUSH : begin
        if(wb_rd) next_wr_fsm_state <= `STATE_WR_POP;
        else next_wr_fsm_state <= `STATE_WR_IDLE;
      end
      `STATE_WR_POP : begin
        if(wdata_avail) next_wr_fsm_state <= `STATE_WR_PUSH;
        else next_wr_fsm_state <= `STATE_WR_IDLE;
      end
      default : begin
        next_wr_fsm_state <= `STATE_WR_IDLE;
      end
    endcase
  end

  // Outputs of state machine (combinatorial)
  always @ (wr_fsm_state) begin
    wda_rst <= 1'b0;
    wpp <= 1'b0;
    w_fifo_en <= 1'b0;
    w_wb_ack <= 1'b0;

    case (wr_fsm_state)
      `STATE_WR_IDLE:;
      `STATE_WR_PUSH : begin
        wda_rst <= 1'b1;
        wpp <= 1'b1;
        w_fifo_en <= 1'b1;
      end
      `STATE_WR_POP : begin
        w_wb_ack <= 1'b1;
        w_fifo_en <= 1'b1;
      end
    endcase
  end

  // Create handshake signals to/from the FIFOs
  assign      fifo_access = !wb_adr_i[2] & wb_sel_i[3];
  assign      wb_rd = wb_cyc_i & wb_stb_i & (~wb_we_i) & fifo_access & (~reg_dlab_bit);
  assign      wb_wr = wb_cyc_i & wb_stb_i & wb_we_i & fifo_access & (~reg_dlab_bit);
  assign      wb_ack_o = wb_fifo_ack | wb_reg_ack;
  assign      wb_err_o = 1'b0;

  // Assign the unimplemented registers
  assign      reg_mcr = 8'h00;  // These bits control modem control lines, unused here
  assign      reg_msr = 8'hB0;  // CD, DSR, CTS true, RI false, no changes indicated
  assign      reg_scr = 8'h00;  // scratch register.

  // Create the simple / combinatorial registers
  assign      rd_fifo_not_full = !(rd_bytes_avail == 4'h8);
  assign      reg_lcr = {reg_dlab_bit, 7'h03};  // Always set for 8n1
  assign      reg_lsr = {1'b0, rd_fifo_not_full, rd_fifo_not_full, 4'b0000, wr_fifo_not_empty};   

  // Create enable bits for the 16550 registers that we actually implement
  assign      reg_dlab_bit_wren = wb_cyc_i & wb_stb_i & wb_we_i & wb_sel_i[0] & (wb_adr_i[2] == 1'b0);
  assign      reg_ier_wren = wb_cyc_i & wb_stb_i & wb_we_i & wb_sel_i[2] & (wb_adr_i[2] == 1'b0) & (~reg_dlab_bit);
  assign      reg_iir_rden = wb_cyc_i & wb_stb_i & (~wb_we_i) & wb_sel_i[1] & (wb_adr_i[2] == 1'b0);
  assign      wb_reg_ack = wb_cyc_i & wb_stb_i & (|wb_sel_i[3:0]) & (reg_dlab_bit | !fifo_access);
  assign      reg_fcr_wren = wb_cyc_i & wb_stb_i & wb_we_i & wb_sel_i[1] & (wb_adr_i[2] == 1'b0);

  assign      rcvr_fifo_rst = reg_fcr_wren & wb_dat_i[9];
  assign      xmit_fifo_rst = reg_fcr_wren & wb_dat_i[10];

  // Create DLAB bit
  always @ (posedge wb_clk_i) begin
    if(wb_rst_i) reg_dlab_bit <= 1'b0;
    else if(reg_dlab_bit_wren) reg_dlab_bit <= wb_dat_i[7];
  end

  // Create IER.  We only use the two LS bits...
  always @ (posedge wb_clk_i) begin
    if(wb_rst_i) reg_ier <= 4'h0;
    else if(reg_ier_wren) reg_ier <= wb_dat_i[19:16];
  end

  // Create IIR (and THR INT arm bit)
  assign rd_fifo_becoming_empty = r_fifo_en & (~rpp) & (rd_bytes_avail == 4'h1);  // "rd fifo" is the WB write FIFO...

  always @ (posedge wb_clk_i) begin
    if(wb_rst_i) thr_int_arm <= 1'b0;
    else if(wb_wr | rd_fifo_becoming_empty) thr_int_arm <= 1'b1;  // Set when WB write fifo becomes empty, or on a write to it
    else if(reg_iir_rden & (~wr_fifo_not_empty)) thr_int_arm <= 1'b0;
  end

  always @ (thr_int_arm or rd_fifo_not_full or wr_fifo_not_empty) begin
    if(wr_fifo_not_empty) iir_gen <= 3'b100;
    else if(thr_int_arm & rd_fifo_not_full) iir_gen <= 3'b010;
    else iir_gen <= 3'b001;
  end 

  assign reg_iir = iir_gen;

  // Create the data lines out to the WB.
  // Always put all 4 bytes on the WB data lines, let the master pick out what it
  // wants.   
  assign bus_data_lo = {data_to_wb, {4'b0000, reg_ier}, {5'b00000, reg_iir}, reg_lcr};
  assign bus_data_hi = {reg_mcr, reg_lsr, reg_msr, reg_scr};
  assign wb_dat_o = (wb_adr_i[2]) ? bus_data_hi : bus_data_lo;

  assign data_from_wb = wb_dat_i[31:24];  // Data to the FIFO

  // Generate interrupt output
  assign int_o = (rd_fifo_not_full & thr_int_arm & reg_ier[1]) | (wr_fifo_not_empty & reg_ier[0]);
endmodule
