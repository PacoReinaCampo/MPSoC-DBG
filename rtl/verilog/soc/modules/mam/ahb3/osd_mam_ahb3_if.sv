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
//              Debug on Chip Interface                                       //
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
 *   Francisco Javier Reina Campo <frareicam@gmail.com>
 */

module osd_mam_ahb3_if #(
  parameter XLEN  = 16, // in bits, must be multiple of 16
  parameter PLEN  = 32,

  //Byte select width
  localparam SW = (XLEN == 32) ? 4 :
                  (XLEN == 16) ? 2 :
                  (XLEN ==  8) ? 1 : 'hx
)
  (
    input                   clk_i,
    input                   rst_i,

    input                   req_valid,  // Start a new memory access request
    output reg              req_ready,  // Acknowledge the new memory access request
    input                   req_we,     // 0: Read, 1: Write
    input      [PLEN  -1:0] req_addr,   // Request base address
    input                   req_burst,  // 0 for single beat access, 1 for incremental burst
    input      [      12:0] req_beats,  // Burst length in number of words

    input                   write_valid,  // Next write data is valid
    input      [XLEN  -1:0] write_data,   // Write data
    input      [XLEN/8-1:0] write_strb,   // Byte strobe if req_burst==0
    output reg              write_ready,  // Acknowledge this data item

    output reg              read_valid,  // Next read data is valid
    output reg [XLEN  -1:0] read_data,   // Read data
    input                   read_ready,  // Acknowledge this data item

    output reg            ahb3_hsel_o,
    output reg [PLEN-1:0] ahb3_haddr_o,
    output reg [XLEN-1:0] ahb3_hwdata_o,
    output reg            ahb3_hwrite_o,
    output     [     2:0] ahb3_hsize_o,
    output reg [     2:0] ahb3_hburst_o,
    output reg [     3:0] ahb3_hprot_o,
    output reg [     1:0] ahb3_htrans_o,
    output                ahb3_hmastlock_o,

    input      [XLEN-1:0] ahb3_hrdata_i,
    input                 ahb3_hready_i,
    input                 ahb3_hresp_i
  );

  enum { STATE_IDLE, STATE_WRITE_LAST, STATE_WRITE_LAST_WAIT,
         STATE_WRITE, STATE_WRITE_WAIT, STATE_READ,
         STATE_READ_WAIT } state, nxt_state;

  logic       nxt_we_o;
  logic [2:0] nxt_cti_o;
  logic [1:0] nxt_bte_o;

  reg   [XLEN-1:0]     read_data_reg;
  logic [XLEN-1:0] nxt_read_data_reg;

  reg   [XLEN-1:0]     dat_o_reg;
  logic [XLEN-1:0] nxt_dat_o_reg;

  logic [PLEN-1:0] nxt_addr_o;

  reg   [12:0]     beats;
  logic [12:0] nxt_beats;

  //registers
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state <= STATE_IDLE;
    end
    else begin
      state <= nxt_state;
    end

    ahb3_hwrite_o <= nxt_we_o;
    ahb3_hburst_o <= nxt_cti_o;
    ahb3_htrans_o <= nxt_bte_o;
    read_data_reg <= nxt_read_data_reg;
    dat_o_reg     <= nxt_dat_o_reg;
    ahb3_haddr_o  <= nxt_addr_o;
    beats         <= nxt_beats;
  end

  assign ahb3_hmastlock_o = ahb3_hsel_o;

  //state & output logic
  always_comb begin
    nxt_state = state;
    nxt_we_o = ahb3_hwrite_o;
    nxt_cti_o = ahb3_hburst_o;
    nxt_bte_o = 2'b0;
    nxt_read_data_reg = read_data_reg;
    nxt_dat_o_reg = dat_o_reg;
    nxt_addr_o = ahb3_haddr_o;
    nxt_beats = beats;
    ahb3_hprot_o = '{default:'1};

    ahb3_hsel_o = 0;
    req_ready   = 0;
    write_ready = 0;
    read_valid  = 0;

    ahb3_hwdata_o = dat_o_reg;
    read_data     = read_data_reg;

    case (state)
      STATE_IDLE: begin
        req_ready = 1;
        nxt_beats = req_beats;
        nxt_addr_o = req_addr;
        if (req_valid) begin
          if (req_we) begin
            nxt_we_o = 1;
            if (req_burst) begin
              if (nxt_beats == 1) begin
                nxt_cti_o = 3'b111;
                if (write_valid) begin
                  nxt_state = STATE_WRITE_LAST;
                  nxt_dat_o_reg = write_data;
                end
                else begin
                  nxt_state = STATE_WRITE_LAST_WAIT;
                end
              end
              else begin
                nxt_cti_o = 3'b010;
                nxt_bte_o = 2'b00;
                if (write_valid) begin
                  nxt_state = STATE_WRITE;
                  nxt_dat_o_reg = write_data;
                end
                else begin
                  nxt_state = STATE_WRITE_WAIT;
                end
              end
            end
            else begin
              nxt_cti_o = 3'b111;
              if (write_valid) begin
                nxt_state = STATE_WRITE_LAST;
                nxt_dat_o_reg = write_data;
              end
              else begin
                nxt_state = STATE_WRITE_LAST_WAIT;
              end
            end
          end
          else begin
            nxt_we_o = 0;
            nxt_state = STATE_READ;
            if (req_burst) begin
              if (nxt_beats == 1) begin
                nxt_cti_o = 3'b111;
              end
              else begin
                nxt_cti_o = 3'b010;
              end
            end
            else begin
              nxt_cti_o = 3'b111;
            end
          end
        end
      end //STATE_IDLE
      STATE_WRITE_LAST_WAIT: begin
        write_ready = 1;
        if (write_valid) begin
          nxt_state = STATE_WRITE_LAST;
          nxt_dat_o_reg = write_data;
        end
      end //STATE_WRITE_LAST_WAIT
      STATE_WRITE_LAST: begin
        ahb3_hsel_o = 1;
        if (ahb3_hready_i) begin
          nxt_state = STATE_IDLE;
          nxt_cti_o = 3'b000;
        end
      end //STATE_WRITE_LAST
      STATE_WRITE_WAIT: begin
        write_ready = 1;
        if (write_valid) begin
          nxt_state = STATE_WRITE;
          nxt_dat_o_reg = write_data;
          nxt_beats = beats - 1;
        end
      end //STATE_WRITE_WAIT
      STATE_WRITE: begin
        ahb3_hsel_o = 1;
        if (ahb3_hready_i) begin
          write_ready = 1;
          nxt_addr_o = ahb3_haddr_o + XLEN/8;
          if (beats == 1) begin
            nxt_cti_o=3'b111;
            if (write_valid) begin
              nxt_state = STATE_WRITE_LAST;
              nxt_dat_o_reg = write_data;
            end
            else begin
              nxt_state = STATE_WRITE_LAST_WAIT;
            end
          end
          else begin
            if (write_valid) begin
              nxt_state = STATE_WRITE;
              nxt_dat_o_reg = write_data;
              nxt_beats = beats - 1;
            end
            else begin
              nxt_state = STATE_WRITE_WAIT;
            end
          end
        end
      end
      STATE_READ: begin
        ahb3_hsel_o = 1;
        if (ahb3_hready_i) begin
          nxt_read_data_reg = ahb3_hrdata_i;
          nxt_beats = beats - 1;
          nxt_addr_o = ahb3_haddr_o + XLEN/8;
          nxt_state = STATE_READ_WAIT;
        end
      end
      STATE_READ_WAIT: begin
        read_valid = 1;
        if (read_ready) begin
          if (beats == 1) begin
            nxt_cti_o = 3'b111;
          end

          if (beats == 0) begin
            nxt_state = STATE_IDLE;
          end
          else begin
            nxt_state = STATE_READ;
          end
        end
      end
    endcase
  end
endmodule
