// Copyright 2016 by the authors
//
// Copyright and related rights are licensed under the Solderpad
// Hardware License, Version 0.51 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a
// copy of the License at http://solderpad.org/licenses/SHL-0.51.
// Unless required by applicable law or agreed to in writing,
// software, hardware and materials distributed under this License is
// distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the
// License.
//
// Authors:
//    Nico Gutmann <nicolai.gutmann@gmail.com>

module osd_mam_bb_if #(
  parameter DATA_WIDTH  = 16, // in bits, must be multiple of 16
  parameter ADDR_WIDTH  = 32,

  //Byte select width
  localparam SW = (DATA_WIDTH == 32) ? 4 :
                  (DATA_WIDTH == 16) ? 2 :
                  (DATA_WIDTH ==  8) ? 1 : 'hx
)
  (
    input                       clk_i,
    input                       rst_i,

    input                       req_valid,  // Start a new memory access request
    output reg                  req_ready,  // Acknowledge the new memory access request
    input                       req_we,     // 0: Read, 1: Write
    input    [ADDR_WIDTH  -1:0] req_addr,   // Request base address
    input                       req_burst,  // 0 for single beat access, 1 for incremental burst
    input    [            12:0] req_beats,  // Burst length in number of words

    input                       write_valid,  // Next write data is valid
    input    [DATA_WIDTH  -1:0] write_data,   // Write data
    input    [DATA_WIDTH/8-1:0] write_strb,   // Byte strobe if req_burst==0
    output reg                  write_ready,  // Acknowledge this data item

    output reg                  read_valid,  // Next read data is valid
    output reg [DATA_WIDTH-1:0] read_data,   // Read data
    input                       read_ready,  // Acknowledge this data item

    output reg [ADDR_WIDTH-1:0] addr_o,
    output reg [DATA_WIDTH-1:0] din_o,
    output reg                  en_o,
    output reg                  we_o,
    input      [DATA_WIDTH-1:0] dout_i
  );

  enum { STATE_IDLE, STATE_WRITE_LAST, STATE_WRITE_LAST_WAIT,
         STATE_WRITE, STATE_WRITE_WAIT, STATE_READ,
         STATE_READ_WAIT } state, nxt_state;

  logic       nxt_we_o;

  reg   [DATA_WIDTH-1:0]     read_data_reg;
  logic [DATA_WIDTH-1:0] nxt_read_data_reg;

  reg   [DATA_WIDTH-1:0]     din_o_reg;
  logic [DATA_WIDTH-1:0] nxt_din_o_reg;

  logic [ADDR_WIDTH-1:0] nxt_addr_o;

  reg   [12:0]               beats;
  logic [12:0]           nxt_beats;

  //registers
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state <= STATE_IDLE;
    end
    else begin
      state <= nxt_state;
    end

    we_o <= nxt_we_o;
    read_data_reg <= nxt_read_data_reg;
    din_o_reg <= nxt_din_o_reg;
    addr_o <= nxt_addr_o;
    beats <= nxt_beats;
  end

  //state & output logic
  always_comb begin
    nxt_state = state;
    nxt_we_o = we_o;
    nxt_read_data_reg = read_data_reg;
    nxt_din_o_reg = din_o_reg;
    nxt_addr_o = addr_o;
    nxt_beats = beats;

    en_o = 0;
    req_ready = 0;
    write_ready = 0;
    read_valid = 0;

    din_o = din_o_reg;
    read_data = read_data_reg;

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
                if (write_valid) begin
                  nxt_state = STATE_WRITE_LAST;
                  nxt_din_o_reg = write_data;
                end
                else begin
                  nxt_state = STATE_WRITE_LAST_WAIT;
                end
              end
              else begin
                if (write_valid) begin
                  nxt_state = STATE_WRITE;
                  nxt_din_o_reg = write_data;
                end
                else begin
                  nxt_state = STATE_WRITE_WAIT;
                end
              end
            end
            else begin
              if (write_valid) begin
                nxt_state = STATE_WRITE_LAST;
                nxt_din_o_reg = write_data;
              end
              else begin
                nxt_state = STATE_WRITE_LAST_WAIT;
              end
            end
          end
          else begin
            nxt_we_o = 0;
            nxt_state = STATE_READ;
          end
        end
      end //STATE_IDLE
      STATE_WRITE_LAST_WAIT: begin
        write_ready = 1;
        if (write_valid) begin
          nxt_state = STATE_WRITE_LAST;
          nxt_din_o_reg = write_data;
        end
      end //STATE_WRITE_LAST_WAIT
      STATE_WRITE_LAST: begin
        en_o = 1;
      end //STATE_WRITE_LAST
      STATE_WRITE_WAIT: begin
        write_ready = 1;
        if (write_valid) begin
          nxt_state = STATE_WRITE;
          nxt_din_o_reg = write_data;
          nxt_beats = beats - 1;
        end
      end //STATE_WRITE_WAIT
      STATE_WRITE: begin
        en_o = 1;
      end // STATE_WRITE
      STATE_READ: begin
        en_o = 1;
      end
      STATE_READ_WAIT: begin
        read_valid = 1;
        if (read_ready) begin
          if (beats == 0) begin
            nxt_state = STATE_IDLE;
          end
          else begin
            nxt_state = STATE_READ;
          end
        end
      end //STATE_READ_WAIT
    endcase
  end
endmodule
