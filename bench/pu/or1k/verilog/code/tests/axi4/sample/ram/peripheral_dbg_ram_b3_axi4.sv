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
//   Paco Reina Campo <pacoreinacampo@queenfield.tech>

module peripheral_dbg_ram_b3_axi4 #(
  // Wishbone parameters
  parameter DW = 32,
  parameter AW = 32,

  // Memory parameters
  parameter MEMORY_FILE    = "",
  parameter MEM_SIZE_BYTES = 32'h0000_5000,  // 20KBytes
  parameter MEM_ADR_WIDTH  = 15
) (
  input axi4_clk_i,
  input axi4_rst_i,

  input [AW-1:0] axi4_adr_i,
  input [DW-1:0] axi4_dat_i,
  input [   3:0] axi4_sel_i,
  input          axi4_we_i,
  input [   1:0] axi4_bte_i,
  input [   2:0] axi4_cti_i,
  input          axi4_cyc_i,
  input          axi4_stb_i,

  output          axi4_ack_o,
  output          axi4_err_o,
  output          axi4_rty_o,
  output [DW-1:0] axi4_dat_o
);

  //////////////////////////////////////////////////////////////////////////////
  // Constants
  //////////////////////////////////////////////////////////////////////////////

  localparam BYTES_PER_DW = DW / 8;
  localparam ADR_WIDTH_FOR_NUM_WORD_BYTES = 2;
  localparam MEM_WORDS = MEM_SIZE_BYTES / BYTES_PER_DW;

  //////////////////////////////////////////////////////////////////////////////
  // Variables
  //////////////////////////////////////////////////////////////////////////////

  // synthesis attribute ram_style of mem is block
  reg  [                                          DW-1:0] mem                                                                                                    [0 : MEM_WORDS-1];

  // Register to address internal memory array
  reg  [(MEM_ADR_WIDTH-ADR_WIDTH_FOR_NUM_WORD_BYTES)-1:0] adr;

  // Register to indicate if the cycle is a Wishbone B3-registered feedback 
  // type access
  reg                                                     axi4_b3_trans;

  // Register to use for counting the addresses when doing burst accesses
  reg  [  MEM_ADR_WIDTH-ADR_WIDTH_FOR_NUM_WORD_BYTES-1:0] burst_adr_counter;

  // Logic to detect if there's a burst access going on
  wire                                                    axi4_b3_trans_start = ((axi4_cti_i == 3'b001) | (axi4_cti_i == 3'b010)) & axi4_stb_i & !axi4_b3_trans & axi4_cyc_i;

  wire                                                    axi4_b3_trans_stop = ((axi4_cti_i == 3'b111) & axi4_stb_i & axi4_b3_trans & axi4_ack_o) | axi4_err_o;

  // Register it locally
  reg  [                                             1:0] axi4_bte_i_r;
  reg  [                                             2:0] axi4_cti_i_r;

  wire                                                    using_burst_adr = axi4_b3_trans;

  wire                                                    burst_access_wrong_axi4_adr = (using_burst_adr & (adr != axi4_adr_i[MEM_ADR_WIDTH-1:2]));

  wire [                                            31:0] wr_data;

  wire                                                    ram_we = axi4_we_i & axi4_ack_o;

  // Error when out of bounds of memory - skip top nibble of address in case
  // this is mapped somewhere other than 0x0.
  wire                                                    addr_err = axi4_cyc_i & axi4_stb_i & (|axi4_adr_i[AW-1-4:MEM_ADR_WIDTH]);

  reg                                                     axi4_ack_o_r;

  //////////////////////////////////////////////////////////////////////////////
  // Tasks
  //////////////////////////////////////////////////////////////////////////////

`ifdef verilator
  task do_readmemh;
    // verilator public
    $readmemh(MEMORY_FILE, mem);
  endtask  // do_readmemh
`endif

  //////////////////////////////////////////////////////////////////////////////
  // Functions
  //////////////////////////////////////////////////////////////////////////////

  // Function to access RAM (for use by Verilator).
  function [31:0] get_mem32;
    // verilator public
    input [AW-1:0] addr;
    get_mem32 = mem[addr];
  endfunction  // get_mem32   

  // Function to access RAM (for use by Verilator).
  function [7:0] get_mem8;
    // verilator public
    input [AW-1:0] addr;
    reg [31:0] temp_word;
    begin
      temp_word = mem[{addr[AW-1:2], 2'd0}];
      // Big endian mapping.
      get_mem8  = (addr[1:0] == 2'b00) ? temp_word[31:24] : (addr[1:0] == 2'b01) ? temp_word[23:16] : (addr[1:0] == 2'b10) ? temp_word[15:8] : temp_word[7:0];
    end
  endfunction  // get_mem8   

  // Function to write RAM (for use by Verilator).
  function set_mem32;
    // verilator public
    input [AW-1:0] addr;
    input [DW-1:0] data;
    begin
      mem[addr] = data;
      set_mem32 = data;  // For avoiding ModelSim warning
    end
  endfunction  // set_mem32

  //////////////////////////////////////////////////////////////////////////////
  // Body
  //////////////////////////////////////////////////////////////////////////////

  always @(posedge axi4_clk_i) begin
    if (axi4_rst_i) begin
      axi4_b3_trans <= 0;
    end else if (axi4_b3_trans_start) begin
      axi4_b3_trans <= 1;
    end else if (axi4_b3_trans_stop) begin
      axi4_b3_trans <= 0;
    end
  end

  always @(posedge axi4_clk_i) begin
    axi4_bte_i_r <= axi4_bte_i;
    axi4_cti_i_r <= axi4_cti_i;
  end

  // Burst address generation logic
  always @(axi4_ack_o or axi4_b3_trans or axi4_b3_trans_start or axi4_bte_i_r or axi4_cti_i_r or axi4_adr_i or adr) begin
    if (axi4_b3_trans_start) begin
      // Kick off burst_adr_counter, this assumes 4-byte words when getting
      // address off incoming Wishbone bus address! 
      // So if DW is no longer 4 bytes, change this!
      burst_adr_counter = axi4_adr_i[MEM_ADR_WIDTH-1:2];
    end else if ((axi4_cti_i_r == 3'b010) & axi4_ack_o & axi4_b3_trans) begin  // Incrementing burst
      case (axi4_bte_i_r)
        2'b00: burst_adr_counter = adr + 1;  // Linear burst
        2'b01: burst_adr_counter[1:0] = adr[1:0] + 1;  // 4-beat wrap burst
        2'b10: burst_adr_counter[2:0] = adr[2:0] + 1;  // 8-beat wrap burst
        2'b11: burst_adr_counter[3:0] = adr[3:0] + 1;  // 16-beat wrap burst
      endcase
    end
  end

  // Address registering logic
  always @(posedge axi4_clk_i) begin
    if (axi4_rst_i) begin
      adr <= 0;
    end else if (using_burst_adr) begin
      adr <= burst_adr_counter;
    end else if (axi4_cyc_i & axi4_stb_i) begin
      adr <= axi4_adr_i[MEM_ADR_WIDTH-1:2];
    end
  end

  assign axi4_rty_o       = 0;

  // mux for data to ram, RMW on part sel != 4'hf
  assign wr_data[31:24] = axi4_sel_i[3] ? axi4_dat_i[31:24] : axi4_dat_o[31:24];
  assign wr_data[23:16] = axi4_sel_i[2] ? axi4_dat_i[23:16] : axi4_dat_o[23:16];
  assign wr_data[15:8]  = axi4_sel_i[1] ? axi4_dat_i[15:8] : axi4_dat_o[15:8];
  assign wr_data[7:0]   = axi4_sel_i[0] ? axi4_dat_i[7:0] : axi4_dat_o[7:0];

  assign axi4_dat_o       = mem[adr];

  // Write logic
  always @(posedge axi4_clk_i) begin
    if (ram_we) begin
      mem[adr] <= wr_data;
    end
  end

  // Ack Logic
  assign axi4_ack_o = axi4_ack_o_r & axi4_stb_i & !(burst_access_wrong_axi4_adr | addr_err);

  // Handle axi4_ack
  always @(posedge axi4_clk_i) begin
    if (axi4_rst_i) begin
      axi4_ack_o_r <= 1'b0;
    end else if (axi4_cyc_i) begin  // We have bus
      if (addr_err & axi4_stb_i) begin
        axi4_ack_o_r <= 1;
      end else if (axi4_cti_i == 3'b000) begin  // Classic cycle acks
        axi4_ack_o_r <= axi4_stb_i ^ axi4_ack_o_r;
      end else if ((axi4_cti_i == 3'b001) | (axi4_cti_i == 3'b010)) begin  // Increment/constant address bursts
        axi4_ack_o_r <= axi4_stb_i;
      end else if (axi4_cti_i == 3'b111) begin  // End of cycle
        axi4_ack_o_r <= axi4_stb_i & !axi4_ack_o_r;
      end
      // if (axi4_cyc_i)
    end else begin
      axi4_ack_o_r <= 0;
    end
  end

  // Error signal generation

  // OR in other errors here...
  assign axi4_err_o = axi4_ack_o_r & axi4_stb_i & (burst_access_wrong_axi4_adr | addr_err);
endmodule
