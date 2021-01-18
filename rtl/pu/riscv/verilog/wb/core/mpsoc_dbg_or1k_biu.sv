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

module mpsoc_dbg_or1k_biu #(
  parameter X              = 2,
  parameter Y              = 2,
  parameter Z              = 2,
  parameter CORES_PER_TILE = 1,
  parameter CPU_ADDR_WIDTH = 32,
  parameter CPU_DATA_WIDTH = 32
)
  (
    // Debug interface signals
    input  logic                      tck_i,
    input  logic                      tlr_i,
    input  logic [               3:0] cpu_select_i,
    input  logic [CPU_ADDR_WIDTH-1:0] data_i,  // Assume short words are in UPPER order bits!
    output logic [CPU_DATA_WIDTH-1:0] data_o,
    input  logic [CPU_DATA_WIDTH-1:0] addr_i,
    input  logic                      strobe_i,
    input  logic                      rd_wrn_i,
    output logic                      rdy_o,

    // OR1K SPR bus signals
    input  logic                                                               cpu_clk_i,
    input  logic                                                               cpu_rstn_i,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_ADDR_WIDTH-1:0] cpu_addr_o,
    input  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] cpu_data_i,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0][CPU_DATA_WIDTH-1:0] cpu_data_o,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_stb_o,
    output logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_we_o,
    input  logic [X-1:0][Y-1:0][Z-1:0][CORES_PER_TILE-1:0]                     cpu_ack_i
  );

  //////////////////////////////////////////////////////////////////
  //
  // Constants
  //
  localparam STATE_IDLE     = 1'h0;
  localparam STATE_TRANSFER = 1'h1;

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  logic [CPU_DATA_WIDTH-1:0] cpu_data_int;
  logic                      cpu_ack_int;
  logic                      cpu_stb_int;

  // Registers
  reg    [CPU_ADDR_WIDTH-1:0] addr_reg;
  reg    [CPU_DATA_WIDTH-1:0] data_in_reg;  // dbg->WB
  reg    [CPU_DATA_WIDTH-1:0] data_out_reg; // WB->dbg
  reg                         wr_reg;
  reg                         str_sync;     // This is 'active-toggle' rather than -high or -low.
  reg                         rdy_sync;     // ditto, active-toggle


  // Sync registers.  TFF indicates TCK domain, WBFF indicates cpu_clk domain
  reg           rdy_sync_tff1;
  reg           rdy_sync_tff2;
  reg           rdy_sync_tff2q;  // used to detect toggles
  reg           str_sync_wbff1;
  reg           str_sync_wbff2;
  reg           str_sync_wbff2q;  // used to detect toggles


  // Control Signals
  reg           data_o_en;    // latch wb_data_i
  reg           rdy_sync_en;  // toggle the rdy_sync signal, indicate ready to TCK domain

  // Internal signals
  wire          start_toggle;  // CPU domain, indicates a toggle on the start strobe

  logic         valid_selection; //set to 1 if value in input selection signal is < X*Y*Z*CORES_PER_TILE

  reg cpu_fsm_state;
  reg next_fsm_state;

  genvar i,j,k,t;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  assign valid_selection = (cpu_select_i < X*Y*Z*CORES_PER_TILE) ? 1'b1 : 1'b0;

  //////////////////////////////////////////////////////
  // TCK clock domain
  // There is no FSM here, just signal latching and clock
  // domain synchronization

  // Latch input data on 'start' strobe, if ready.
  always @ (posedge tck_i or posedge tlr_i) begin
    if(tlr_i) begin
      addr_reg    <= 32'h0;
      data_in_reg <= 32'h0;
      wr_reg      <= 1'b0;
    end
    else begin
      if(strobe_i && rdy_o) begin
        addr_reg <= addr_i;
        if(!rd_wrn_i) data_in_reg <= data_i;
        wr_reg <= ~rd_wrn_i;
      end 
    end
  end

  // Create toggle-active strobe signal for clock sync.  This will start a transaction
  // to the CPU once the toggle propagates to the FSM in the cpu_clk domain.
  always @ (posedge tck_i or posedge tlr_i) begin
    if      (tlr_i)             str_sync <= 1'b0;
    else if (strobe_i && rdy_o) str_sync <= ~str_sync;
  end 

  // Create rdy_o output.  Set on reset, clear on strobe (if set), set on input toggle
  always @ (posedge tck_i or posedge tlr_i) begin
    if(tlr_i) begin
      rdy_sync_tff1  <= 1'b0;
      rdy_sync_tff2  <= 1'b0;
      rdy_sync_tff2q <= 1'b0;
      rdy_o          <= 1'b1; 
    end
    else begin  
      rdy_sync_tff1  <= rdy_sync;       // Synchronize the ready signal across clock domains
      rdy_sync_tff2  <= rdy_sync_tff1;
      rdy_sync_tff2q <= rdy_sync_tff2;  // used to detect toggles
      if(strobe_i && rdy_o) 
        rdy_o <= 1'b0;
      else if(rdy_sync_tff2 != rdy_sync_tff2q) 
        rdy_o <= 1'b1;
    end
  end

  // Direct assignments, unsynchronized

  assign data_o = data_out_reg;

  generate
    for (i=0;i<X;i=i+1) begin
      for (j=0;j<Y;j=j+1) begin
        for (k=0;k<Z;k=k+1) begin
          for (t=0;t<CORES_PER_TILE;t=t+1) begin
            always @(*) begin
              if (cpu_select_i == i*j*k*t) begin
                cpu_data_o [i][j][k][t] = data_in_reg;
                cpu_we_o   [i][j][k][t] = wr_reg;
                cpu_addr_o [i][j][k][t] = addr_reg;
                cpu_stb_o  [i][j][k][t] = cpu_stb_int;
              end
              else begin   
                cpu_data_o [i][j][k][t] =  'h0;
                cpu_we_o   [i][j][k][t] = 1'b0;
                cpu_addr_o [i][j][k][t] =  'h0;
                cpu_stb_o  [i][j][k][t] = 1'b0;
              end
            end
          end
        end
      end
    end
  endgenerate

  generate
    for (i=0;i<X;i=i+1) begin
      for (j=0;j<Y;j=j+1) begin
        for (k=0;k<Z;k=k+1) begin
          for (t=0;t<CORES_PER_TILE;t=t+1) begin
            always @(*) begin
              cpu_data_int =  'h0;
              cpu_ack_int  = 1'b0;
              if (cpu_select_i == i*j*k*t) begin
                cpu_data_int = cpu_data_i[i][j][k][t];
                cpu_ack_int  = cpu_ack_i[i][j][k][t];
              end
            end
          end
        end
      end
    end
  endgenerate

  // CPU clock domain

  // synchronize the start strobe
  always @ (posedge cpu_clk_i or negedge cpu_rstn_i) begin
    if(~cpu_rstn_i) begin
      str_sync_wbff1  <= 1'b0;
      str_sync_wbff2  <= 1'b0;
      str_sync_wbff2q <= 1'b0;      
    end
    else begin
      str_sync_wbff1  <= str_sync;
      str_sync_wbff2  <= str_sync_wbff1;
      str_sync_wbff2q <= str_sync_wbff2;  // used to detect toggles
    end
  end

  assign start_toggle = (str_sync_wbff2 != str_sync_wbff2q);

  // CPU->dbg data register
  always @ (posedge cpu_clk_i or negedge cpu_rstn_i) begin
    if(~cpu_rstn_i)    data_out_reg <= 32'h0;
    else if(data_o_en) data_out_reg <= cpu_data_int;
  end

  // Create a toggle-active ready signal to send to the TCK domain
  always @ (posedge cpu_clk_i or negedge cpu_rstn_i) begin
    if(~cpu_rstn_i)      rdy_sync <= 1'b0;
    else if(rdy_sync_en) rdy_sync <= ~rdy_sync;
  end

  // Small state machine to create OR1K SPR bus accesses
  // Not much more that an 'in_progress' bit, but easier
  // to read.  Deals with single-cycle and multi-cycle
  // accesses.

  // Sequential bit
  always @ (posedge cpu_clk_i or negedge cpu_rstn_i) begin
    if(~cpu_rstn_i) cpu_fsm_state <= STATE_IDLE;
    else            cpu_fsm_state <= next_fsm_state; 
  end

  // Determination of next state (combinatorial)
  always @ (cpu_fsm_state or start_toggle or cpu_ack_int) begin
    case (cpu_fsm_state)
      STATE_IDLE: begin
        if(start_toggle && !cpu_ack_int) 
          next_fsm_state <= STATE_TRANSFER;  // Don't go to next state for 1-cycle transfer
        else 
          next_fsm_state <= STATE_IDLE;
      end
      STATE_TRANSFER: begin
        if(cpu_ack_int) 
          next_fsm_state <= STATE_IDLE;
        else 
          next_fsm_state <= STATE_TRANSFER;
      end
    endcase
  end

  // Outputs of state machine (combinatorial)
  always @ (cpu_fsm_state or start_toggle or cpu_ack_int or wr_reg) begin
    rdy_sync_en = 1'b0;
    data_o_en   = 1'b0;
    cpu_stb_int = 1'b0;
    case (cpu_fsm_state)
      STATE_IDLE: begin
        if(start_toggle) begin
          cpu_stb_int = 1'b1;
          if(cpu_ack_int) begin
            rdy_sync_en = 1'b1;
          end
          else if (cpu_ack_int && !wr_reg) begin  // latch read data
            data_o_en = 1'b1;
          end
        end
      end
      STATE_TRANSFER: begin
        cpu_stb_int = 1'b1;  // OR1K behavioral model needs this.  OR1200 should be indifferent.
        if(cpu_ack_int) begin
          data_o_en = 1'b1;
          rdy_sync_en = 1'b1;
        end
      end
    endcase
  end
endmodule
