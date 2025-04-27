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

// Top module
module peripheral_dbg_pu_riscv_bb_tl #(
  parameter LITTLE_ENDIAN = 1,
  parameter ADDR_WIDTH    = 32,
  parameter DATA_WIDTH    = 32
) (
  // Debug interface signals
  input                       biu_clk,
  input                       biu_rst,
  input      [DATA_WIDTH-1:0] biu_di,
  output reg [DATA_WIDTH-1:0] biu_do,
  input      [ADDR_WIDTH-1:0] biu_addr,
  input                       biu_strb,
  input                       biu_rw,
  output reg                  biu_rdy,
  output reg                  biu_err,
  input      [           3:0] biu_word_size,

  // AHB Master signals
  input                       HCLK,
  input                       HRESETn,
  output                      HSEL,
  output reg [ADDR_WIDTH-1:0] HADDR,
  output reg [DATA_WIDTH-1:0] HWDATA,
  input      [DATA_WIDTH-1:0] HRDATA,
  output reg                  HWRITE,
  output reg [           2:0] HSIZE,
  output     [           2:0] HBURST,
  output     [           3:0] HPROT,
  output reg [           1:0] HTRANS,
  output                      HMASTLOCK,
  input                       HREADY,
  input                       HRESP
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  localparam IDLE = 2'b10;
  localparam ADDRESS = 2'b01;
  localparam DATA = 2'b00;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  logic [DATA_WIDTH-1:0] data_out_reg;  // AHB->dbg
  logic                  str_sync;  // This is 'active-toggle' rather than -high or -low.
  logic                  rdy_sync;  // ditto, active-toggle

  // Sync registers.  TFF indicates TCK domain, AFF indicates AHB domain
  logic [           1:0] ahb_rstn_sync;
  logic                  ahb_rstn;
  logic                  rdy_sync_tff1;
  logic                  rdy_sync_tff2;
  logic                  rdy_sync_tff2q;  // used to detect toggles
  logic                  str_sync_aff1;
  logic                  str_sync_aff2;
  logic                  str_sync_aff2q;  // used to detect toggles

  // Internal signals
  logic                  start_toggle;  // AHB domain, indicates a toggle on the start strobe
  logic                  start_toggle_hold;  // hold start_toggle if AHB bus busy (not-ready)
  logic                  ahb_transfer_ack;  // AHB bus responded to data transfer

  // AHB FSM
  logic [           1:0] ahb_fsm_state;

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////////////
  // TCK clock domain
  //
  // There is no FSM here, just signal latching and clock domain synchronization

  // Create byte enable signals from word_size and address
  always @(posedge biu_clk) begin
    if (biu_strb && biu_rdy) begin
      case (biu_word_size)
        'h1:     HSIZE <= `HSIZE_BYTE;
        'h2:     HSIZE <= `HSIZE_HWORD;
        'h4:     HSIZE <= `HSIZE_WORD;
        default: HSIZE <= `HSIZE_DWORD;
      endcase
    end
  end

  generate
    if (DATA_WIDTH == 32) begin
      always @(posedge biu_clk) begin
        if (biu_strb && biu_rdy) begin
          case (biu_word_size)
            'h1:     HWDATA <= {4{biu_di[31-:8]}};
            'h2:     HWDATA <= {2{biu_di[31-:16]}};
            default: HWDATA <= biu_di;
          endcase
        end
      end
    end else begin  // DATA_WIDTH == 64
      always @(posedge biu_clk) begin
        if (biu_strb && biu_rdy) begin
          case (biu_word_size)
            'h1:     HWDATA <= {8{biu_di[63-:8]}};
            'h2:     HWDATA <= {4{biu_di[63-:16]}};
            'h4:     HWDATA <= {2{biu_di[63-:32]}};
            default: HWDATA <= biu_di;
          endcase
        end
      end
    end
  endgenerate

  // Latch input data on 'start' strobe, if ready.
  always @(posedge biu_clk, posedge biu_rst) begin
    if (biu_rst) begin
      HADDR  <= 'h0;
      HWRITE <= 'b0;
    end else if (biu_strb && biu_rdy) begin
      HADDR  <= biu_addr;
      HWRITE <= ~biu_rw;
    end
  end

  // Create toggle-active strobe signal for clock sync.  This will start a transaction
  // on the AHB once the toggle propagates to the FSM in the AHB domain.
  always @(posedge biu_clk, posedge biu_rst) begin
    if (biu_rst) begin
      str_sync <= 1'b0;
    end else if (biu_strb && biu_rdy) begin
      str_sync <= ~str_sync;
    end
  end

  // Create biu_rdy output.  Set on reset, clear on strobe (if set), set on input toggle
  always @(posedge biu_clk, posedge biu_rst) begin
    if (biu_rst) begin
      rdy_sync_tff1  <= 1'b0;
      rdy_sync_tff2  <= 1'b0;
      rdy_sync_tff2q <= 1'b0;
      biu_rdy        <= 1'b1;
    end else begin
      rdy_sync_tff1  <= rdy_sync;  // Synchronize the ready signal across clock domains
      rdy_sync_tff2  <= rdy_sync_tff1;
      rdy_sync_tff2q <= rdy_sync_tff2;  // used to detect toggles

      if (biu_strb && biu_rdy) begin
        biu_rdy <= 1'b0;
      end else if (rdy_sync_tff2 != rdy_sync_tff2q) begin
        biu_rdy <= 1'b1;
      end
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // AHB clock domain
  //

  // synchronize asynchronous active high reset
  always @(posedge HCLK, posedge biu_rst) begin
    if (biu_rst) begin
      ahb_rstn_sync <= {$bits(ahb_rstn_sync) {1'b0}};
    end else begin
      ahb_rstn_sync <= {1'b1, ahb_rstn_sync[$bits(ahb_rstn_sync)-1:1]};
    end
  end

  assign ahb_rstn = ~(~HRESETn | ~ahb_rstn_sync[0]);

  // synchronize the start strobe
  always @(posedge HCLK, negedge ahb_rstn) begin
    if (!ahb_rstn) begin
      str_sync_aff1  <= 1'b0;
      str_sync_aff2  <= 1'b0;
      str_sync_aff2q <= 1'b0;
    end else begin
      str_sync_aff1  <= str_sync;
      str_sync_aff2  <= str_sync_aff1;
      str_sync_aff2q <= str_sync_aff2;  // used to detect toggles
    end
  end

  assign start_toggle = (str_sync_aff2 != str_sync_aff2q);

  always @(posedge HCLK, negedge ahb_rstn) begin
    if (!ahb_rstn) begin
      start_toggle_hold <= 1'b0;
    end else begin
      start_toggle_hold <= ~ahb_transfer_ack & (start_toggle | start_toggle_hold);
    end
  end

  // Bus Error register
  always @(posedge HCLK, negedge ahb_rstn) begin
    if (!ahb_rstn) begin
      biu_err <= 1'b0;
    end else if (ahb_transfer_ack) begin
      biu_err <= HRESP;
    end
  end

  // Received data register
  generate
    if (DATA_WIDTH == 32) begin
      always @(posedge HCLK) begin
        if (ahb_transfer_ack) begin
          case (biu_word_size)
            'h1: begin
              case (HADDR[1:0])
                2'b00: biu_do <= LITTLE_ENDIAN ? {24'h0, HRDATA[7-:8]} : {24'h0, HRDATA[31-:8]};
                2'b01: biu_do <= LITTLE_ENDIAN ? {24'h0, HRDATA[15-:8]} : {24'h0, HRDATA[23-:8]};
                2'b10: biu_do <= LITTLE_ENDIAN ? {24'h0, HRDATA[23-:8]} : {24'h0, HRDATA[15-:8]};
                2'b11: biu_do <= LITTLE_ENDIAN ? {24'h0, HRDATA[31-:8]} : {24'h0, HRDATA[7-:8]};
              endcase
            end
            'h2: begin
              case (HADDR[1])
                1'b0: biu_do <= LITTLE_ENDIAN ? {16'h0, HRDATA[15-:16]} : {16'h0, HRDATA[31-:16]};
                2'b1: biu_do <= LITTLE_ENDIAN ? {16'h0, HRDATA[31-:16]} : {16'h0, HRDATA[15-:16]};
              endcase
            end
            default: begin
              biu_do <= HRDATA;
            end
          endcase
        end
      end
    end else begin  // DATA_WIDTH == 64

      always @(posedge HCLK) begin
        if (ahb_transfer_ack) begin
          case (biu_word_size)
            'h1: begin
              case (HADDR[2:0])
                3'b000: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[7-:8]} : {56'h0, HRDATA[63-:8]};
                3'b001: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[15-:8]} : {56'h0, HRDATA[55-:8]};
                3'b010: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[23-:8]} : {56'h0, HRDATA[47-:8]};
                3'b011: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[31-:8]} : {56'h0, HRDATA[39-:8]};
                3'b100: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[39-:8]} : {56'h0, HRDATA[31-:8]};
                3'b101: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[47-:8]} : {56'h0, HRDATA[23-:8]};
                3'b110: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[55-:8]} : {56'h0, HRDATA[15-:8]};
                3'b111: biu_do <= LITTLE_ENDIAN ? {56'h0, HRDATA[63-:8]} : {56'h0, HRDATA[7-:8]};
              endcase
            end
            'h2: begin
              case (HADDR[2:1])
                2'b00: biu_do <= LITTLE_ENDIAN ? {48'h0, HRDATA[15-:16]} : {48'h0, HRDATA[63-:16]};
                2'b01: biu_do <= LITTLE_ENDIAN ? {48'h0, HRDATA[31-:16]} : {48'h0, HRDATA[47-:16]};
                2'b10: biu_do <= LITTLE_ENDIAN ? {48'h0, HRDATA[47-:16]} : {48'h0, HRDATA[31-:16]};
                2'b11: biu_do <= LITTLE_ENDIAN ? {48'h0, HRDATA[63-:16]} : {48'h0, HRDATA[15-:16]};
              endcase
            end
            'h4: begin
              case (HADDR[2])
                1'b0: biu_do <= LITTLE_ENDIAN ? {32'h0, HRDATA[31-:32]} : {16'h0, HRDATA[63-:32]};
                2'b1: biu_do <= LITTLE_ENDIAN ? {32'h0, HRDATA[63-:32]} : {16'h0, HRDATA[31-:32]};
              endcase
            end
            default: begin
              biu_do <= HRDATA;
            end
          endcase
        end
      end
    end
  endgenerate

  // Create a toggle-active ready signal to send to the TCK domain
  always @(posedge HCLK, negedge ahb_rstn) begin
    if (!ahb_rstn) begin
      rdy_sync <= 1'b0;
    end else if (ahb_transfer_ack) begin
      rdy_sync <= ~rdy_sync;
    end
  end

  // State machine to create AHB accesses

  assign ahb_transfer_ack = HREADY & (ahb_fsm_state == DATA);

  assign HSEL             = 1'b1;
  assign HPROT            = `HPROT_DATA | `HPROT_PRIVILEGED | `HPROT_NON_BUFFERABLE | `HPROT_NON_CACHEABLE;
  assign HMASTLOCK        = 1'b0;

  always @(posedge HCLK, negedge ahb_rstn) begin
    if (!ahb_rstn) begin
      HTRANS        <= `HTRANS_IDLE;
      ahb_fsm_state <= IDLE;
    end else begin
      case (ahb_fsm_state)
        IDLE:
        if (start_toggle || start_toggle_hold) begin
          HTRANS        <= `HTRANS_NONSEQ;
          ahb_fsm_state <= ADDRESS;
        end
        ADDRESS: begin
          HTRANS        <= `HTRANS_IDLE;
          ahb_fsm_state <= DATA;
        end
        DATA: if (HREADY) ahb_fsm_state <= IDLE;
        default: begin
          HTRANS        <= `HTRANS_IDLE;
          ahb_fsm_state <= IDLE;
        end
      endcase
    end
  end

  // Only single accesses; no bursts
  assign HBURST = `HBURST_SINGLE;
endmodule
