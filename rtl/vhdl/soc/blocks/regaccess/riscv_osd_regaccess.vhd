-- Converted from rtl/verilog/blocks/regaccess/riscv_osd_regaccess.sv
-- by verilog2vhdl - QueenField

--//////////////////////////////////////////////////////////////////////////////
--                                            __ _      _     _               //
--                                           / _(_)    | |   | |              //
--                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
--               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
--              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
--               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
--                  | |                                                       //
--                  |_|                                                       //
--                                                                            //
--                                                                            //
--              MPSoC-RISCV CPU                                               //
--              Degub Interface                                               //
--              AMBA3 AHB-Lite Bus Interface                                  //
--                                                                            //
--//////////////////////////////////////////////////////////////////////////////

-- Copyright (c) 2018-2019 by the author(s)
-- *
-- * Permission is hereby granted, free of charge, to any person obtaining a copy
-- * of this software and associated documentation files (the "Software"), to deal
-- * in the Software without restriction, including without limitation the rights
-- * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- * copies of the Software, and to permit persons to whom the Software is
-- * furnished to do so, subject to the following conditions:
-- *
-- * The above copyright notice and this permission notice shall be included in
-- * all copies or substantial portions of the Software.
-- *
-- * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- * THE SOFTWARE.
-- *
-- * =============================================================================
-- * Author(s):
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_mpsoc_pkg.all;
use work.riscv_dbg_pkg.all;

entity riscv_osd_regaccess is
  generic (
    XLEN : integer := 64;
    PLEN : integer := 64;

    MAX_REG_SIZE : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    id : in std_logic_vector(XLEN-1 downto 0);

    debug_in_data  : in  std_logic_vector(63 downto 0);
    debug_in_last  : in  std_logic;
    debug_in_valid : in  std_logic;
    debug_in_ready : out std_logic;

    debug_out_data  : out std_logic_vector(XLEN-1 downto 0);
    debug_out_last  : out std_logic;
    debug_out_valid : out std_logic;
    debug_out_ready : in  std_logic;

    reg_request : out std_logic;
    reg_write   : out std_logic;
    reg_addr    : out std_logic_vector(PLEN-1 downto 0);
    reg_size    : out std_logic_vector(1 downto 0);
    reg_wdata   : out std_logic_vector(MAX_REG_SIZE-1 downto 0);
    reg_ack     : in  std_logic;
    reg_err     : in  std_logic;
    reg_rdata   : in  std_logic_vector(MAX_REG_SIZE-1 downto 0);

    event_dest : out std_logic_vector(XLEN-1 downto 0);
    stall      : out std_logic
  );
end riscv_osd_regaccess;

architecture RTL of riscv_osd_regaccess is

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant ACCESS_SIZE_16  : std_logic_vector(1 downto 0) := "00";
  constant ACCESS_SIZE_32  : std_logic_vector(1 downto 0) := "01";
  constant ACCESS_SIZE_64  : std_logic_vector(1 downto 0) := "10";
  constant ACCESS_SIZE_128 : std_logic_vector(1 downto 0) := "11";

  constant MAX_REQ_SIZE : integer := to_integer(unsigned(ACCESS_SIZE_64));

  -- base register addresses
  constant REG_MOD_VENDOR     : std_logic_vector(63 downto 0) := X"0000000000000000";
  constant REG_MOD_TYPE       : std_logic_vector(63 downto 0) := X"0000000000000001";
  constant REG_MOD_VERSION    : std_logic_vector(63 downto 0) := X"0000000000000002";
  constant REG_MOD_CS         : std_logic_vector(63 downto 0) := X"0000000000000003";
  constant REG_MOD_EVENT_DEST : std_logic_vector(63 downto 0) := X"0000000000000004";

  constant REG_MOD_CS_ACTIVE : integer := 0;

  -- State machine
  constant STATE_IDLE           : std_logic_vector(3 downto 0) := "0000";
  constant STATE_REQ_HDR_SRC    : std_logic_vector(3 downto 0) := "0001";
  constant STATE_REQ_HDR_FLAGS  : std_logic_vector(3 downto 0) := "0010";
  constant STATE_ADDR           : std_logic_vector(3 downto 0) := "0011";
  constant STATE_WRITE          : std_logic_vector(3 downto 0) := "0100";
  constant STATE_RESP_HDR_DEST  : std_logic_vector(3 downto 0) := "0101";
  constant STATE_RESP_HDR_SRC   : std_logic_vector(3 downto 0) := "0110";
  constant STATE_RESP_HDR_FLAGS : std_logic_vector(3 downto 0) := "0111";
  constant STATE_RESP_VALUE     : std_logic_vector(3 downto 0) := "1000";
  constant STATE_DROP           : std_logic_vector(3 downto 0) := "1001";
  constant STATE_EXT_START      : std_logic_vector(3 downto 0) := "1010";
  constant STATE_EXT_WAIT       : std_logic_vector(3 downto 0) := "1011";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Registers
  signal mod_cs_active      : std_logic;
  signal nxt_mod_cs_active  : std_logic;
  signal mod_event_dest     : std_logic_vector(XLEN-1 downto 0);
  signal nxt_mod_event_dest : std_logic_vector(XLEN-1 downto 0);

  -- State machine
  signal state     : std_logic_vector(3 downto 0);
  signal nxt_state : std_logic_vector(3 downto 0);

  -- Local request/response data
  signal req_write         : std_logic;
  signal req_size          : std_logic_vector(1 downto 0);
  signal word_it           : std_logic_vector(2 downto 0);
  signal req_addr          : std_logic_vector(63 downto 0);
  signal reqresp_value     : std_logic_vector(MAX_REG_SIZE-1 downto 0);
  signal resp_dest         : std_logic_vector(XLEN-1 downto 0);
  signal resp_error        : std_logic;
  signal nxt_req_write     : std_logic;
  signal nxt_req_size      : std_logic_vector(1 downto 0);
  signal nxt_word_it       : std_logic_vector(2 downto 0);
  signal nxt_req_addr      : std_logic_vector(PLEN-1 downto 0);
  signal nxt_reqresp_value : std_logic_vector(MAX_REG_SIZE-1 downto 0);
  signal nxt_resp_dest     : std_logic_vector(XLEN-1 downto 0);
  signal nxt_resp_error    : std_logic;

  signal reg_addr_is_ext   : std_logic;
  signal reg_addr_internal : std_logic_vector(8 downto 0);

  signal stall_sgn : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  stall_sgn <= not mod_cs_active
               when CAN_STALL = '1' else '0';

  stall <= stall_sgn;

  event_dest <= mod_event_dest;

  -- handle the base addresses 0x0000 - 0x01ff as "internal"
  reg_addr_is_ext   <= to_stdlogic(debug_in_data(15 downto 9) /= "0000000");
  reg_addr_internal <= debug_in_data(8 downto 0);

  reg_write <= req_write;
  reg_addr  <= req_addr;
  reg_size  <= req_size;
  reg_wdata <= reqresp_value;

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        state          <= STATE_IDLE;
        mod_cs_active  <= '0';
        mod_event_dest <= std_logic_vector(to_unsigned(MOD_EVENT_DEST_DEFAULT, XLEN));
        req_write      <= '0';
        req_addr       <= (others => '0');
        req_size       <= (others => '0');
        reqresp_value  <= (others => '0');
      else
        state          <= nxt_state;
        mod_cs_active  <= nxt_mod_cs_active;
        mod_event_dest <= nxt_mod_event_dest;
        req_write      <= nxt_req_write;
        req_addr       <= nxt_req_addr;
        req_size       <= nxt_req_size;
        reqresp_value  <= nxt_reqresp_value;
      end if;
      resp_dest  <= nxt_resp_dest;
      resp_error <= nxt_resp_error;
      word_it    <= nxt_word_it;
    end if;
  end process;

  processing_2 : process (debug_in_data, debug_in_last, debug_in_valid, debug_out_ready, id, mod_cs_active, mod_event_dest, nxt_resp_error, reg_ack, reg_addr_is_ext, reg_err, reg_rdata, req_addr, req_addr(15 downto 9), req_size, req_write, reqresp_value, resp_dest, resp_error, stall_sgn, state, word_it)
    variable state_debug : std_logic_vector(1 downto 0);
  begin
    nxt_state <= state;

    nxt_req_write     <= req_write;
    nxt_req_size      <= req_size;
    nxt_word_it       <= word_it;
    nxt_req_addr      <= req_addr;
    nxt_resp_dest     <= resp_dest;
    nxt_reqresp_value <= reqresp_value;
    nxt_resp_error    <= resp_error;

    nxt_mod_cs_active  <= mod_cs_active;
    nxt_mod_event_dest <= mod_event_dest;

    debug_in_ready <= '0';

    debug_out_data  <= (others => '0');
    debug_out_last  <= '0';
    debug_out_valid <= '0';

    reg_request <= '0';

    case (state) is
      when STATE_IDLE =>
        debug_in_ready <= '1';
        if (debug_in_valid = '1') then
          nxt_state <= STATE_REQ_HDR_SRC;
        end if;
      when STATE_REQ_HDR_SRC =>
        debug_in_ready <= '1';
        nxt_resp_dest  <= debug_in_data;
        nxt_resp_error <= '0';
        nxt_state      <= STATE_REQ_HDR_FLAGS;
      when STATE_REQ_HDR_FLAGS =>
        debug_in_ready <= '1';
        nxt_req_write  <= debug_in_data(12);
        nxt_req_size   <= debug_in_data(11 downto 10);
        if (to_unsigned(MAX_REQ_SIZE, 2) < unsigned(debug_in_data(11 downto 10))) then
          nxt_resp_error <= '1';
          nxt_state      <= STATE_DROP;
        else
          case (state_debug) is
            when ACCESS_SIZE_16 =>
              nxt_word_it <= "000";
            when ACCESS_SIZE_32 =>
              nxt_word_it <= "001";
            when ACCESS_SIZE_64 =>
              nxt_word_it <= "011";
            when ACCESS_SIZE_128 =>
              nxt_word_it <= "111";
            when others =>
              null;
          end case;
          if (debug_in_valid = '1') then
            if (reduce_or(debug_in_data(15 downto 14)) = '1') then
              nxt_state <= STATE_DROP;
            else
              nxt_state <= STATE_ADDR;
            end if;
          end if;
        end if;
      when STATE_ADDR =>
        debug_in_ready <= '1';
        if (reg_addr_is_ext = '1') then
          nxt_req_addr <= debug_in_data;
          if (debug_in_valid = '1') then
            if (req_write = '1') then
              nxt_reqresp_value <= (others => '0');
              nxt_state         <= STATE_WRITE;
            else
              nxt_state <= STATE_EXT_START;
            end if;
          end if;
        elsif (req_write = '1') then
          -- LOCAL WRITE
          if (req_size /= ACCESS_SIZE_16) then
            -- only 16 bit writes are supported for local writes
            nxt_resp_error <= '1';
          else
            nxt_req_addr <= debug_in_data;
            case (debug_in_data) is
              when REG_MOD_EVENT_DEST =>
                nxt_resp_error <= '0';
              when REG_MOD_CS =>
                nxt_resp_error <= '0';
              when others =>
                nxt_resp_error <= '1';
            end case;
          end if;
        else  -- case (debug_in_data)
          -- if (nxt_req_write)
          -- LOCAL READ
          case (debug_in_data) is
            when REG_MOD_VENDOR =>
              nxt_reqresp_value <= std_logic_vector(to_unsigned(MOD_VENDOR, MAX_REG_SIZE));
            when REG_MOD_TYPE =>
              nxt_reqresp_value <= std_logic_vector(to_unsigned(MOD_TYPE, MAX_REG_SIZE));
            when REG_MOD_VERSION =>
              nxt_reqresp_value <= std_logic_vector(to_unsigned(MOD_VERSION, MAX_REG_SIZE));
            when REG_MOD_CS =>
              nxt_reqresp_value <= (MAX_REG_SIZE-1 downto 1 => '0') & not stall_sgn;
            when REG_MOD_EVENT_DEST =>
              nxt_reqresp_value <= mod_event_dest;
            when others =>
              nxt_resp_error <= '1';
          end case;
          -- case (debug_in_data)
          if (debug_in_valid = '1') then
            if (req_write = '1') then
              if (debug_in_last = '1') then
                nxt_resp_error <= '1';
                nxt_state      <= STATE_RESP_HDR_DEST;
              elsif (nxt_resp_error = '1') then
                nxt_state <= STATE_DROP;
              else
                nxt_reqresp_value <= (others => '0');
                nxt_state         <= STATE_WRITE;
              end if;
            elsif (debug_in_last = '1') then
              nxt_state <= STATE_RESP_HDR_DEST;
            else
              nxt_state <= STATE_DROP;
            end if;
          end if;
        end if;
      -- case: STATE_ADDR
      when STATE_WRITE =>
        debug_in_ready <= '1';
        if (debug_in_valid = '1') then
          if (req_addr(15 downto 9) /= "0000000") then
            nxt_reqresp_value <= reqresp_value  or std_logic_vector(unsigned(debug_in_data) sll to_integer(unsigned(word_it))*16);
            if (word_it = "000") then
              if (debug_in_last = '1') then
                nxt_state <= STATE_EXT_START;
              else
                nxt_state <= STATE_DROP;
              end if;
            elsif (debug_in_last = '1') then
              nxt_resp_error <= '1';
              nxt_state      <= STATE_RESP_HDR_DEST;
            else
              nxt_word_it <= std_logic_vector(unsigned(word_it)-"001");
            end if;
          else
            nxt_reqresp_value <= debug_in_data;
            case (req_addr) is
              when REG_MOD_CS =>
                nxt_mod_cs_active <= debug_in_data(REG_MOD_CS_ACTIVE);
                nxt_resp_error    <= '0';
              when REG_MOD_EVENT_DEST =>
                nxt_mod_event_dest <= debug_in_data;
                nxt_resp_error     <= '0';
              when others =>
                null;
            end case;
            -- case (req_addr)
            if (debug_in_last = '1') then
              nxt_state <= STATE_RESP_HDR_DEST;
            else
              nxt_state <= STATE_DROP;
            end if;
          end if;
        end if;
      when STATE_RESP_HDR_DEST =>
        debug_out_valid <= '1';
        debug_out_data  <= resp_dest;
        if (debug_out_ready = '1') then
          nxt_state <= STATE_RESP_HDR_SRC;
        end if;
      when STATE_RESP_HDR_SRC =>
        debug_out_valid <= '1';
        debug_out_data  <= id;
        if (debug_out_ready = '1') then
          nxt_state <= STATE_RESP_HDR_FLAGS;
        end if;
      when STATE_RESP_HDR_FLAGS =>
        debug_out_valid              <= '1';
        debug_out_data(9 downto 0)   <= (others => '0');  -- reserved
        debug_out_data(15 downto 14) <= (others => '0');  -- TYPE == REG
        -- TYPE_SUB
        if (req_write = '1') then
          if (resp_error = '1') then
            debug_out_data(13 downto 10) <= "1111";  -- RESP_WRITE_REG_ERROR
          else                                       -- RESP_WRITE_REG_SUCCESS
            debug_out_data(13 downto 10) <= "1110";
          end if;
        elsif (resp_error = '1') then
          debug_out_data(13 downto 10) <= "1100";    -- RESP_READ_REG_ERROR
        else                                         -- RESP_READ_REG_SUCCESS_*
          debug_out_data(13 downto 10) <= ("10" & req_size);
        end if;
        debug_out_last <= resp_error or req_write;
        if (debug_out_ready = '1') then
          if (resp_error = '1' or req_write = '1') then
            nxt_state <= STATE_IDLE;
          else
            nxt_state <= STATE_RESP_VALUE;
          end if;
        end if;
      when STATE_RESP_VALUE =>
        debug_out_valid <= '1';
        debug_out_data  <= std_logic_vector(unsigned(reqresp_value) srl to_integer(unsigned(word_it))*16);
        if (debug_out_ready = '1') then
          if (word_it = "000") then
            debug_out_last <= '1';
            nxt_state      <= STATE_IDLE;
          else
            nxt_word_it <= std_logic_vector(unsigned(word_it)-"001");
          end if;
        end if;
      when STATE_EXT_START =>
        reg_request <= '1';
        if (reg_ack = '1' or reg_err = '1') then
          nxt_reqresp_value <= reg_rdata;
          nxt_resp_error    <= reg_err;
          nxt_state         <= STATE_RESP_HDR_DEST;
        end if;
      when STATE_DROP =>
        debug_in_ready <= '1';
        if (debug_in_valid = '1' and debug_in_last = '1') then
          nxt_state <= STATE_RESP_HDR_DEST;
        end if;
      when others =>
        null;
    end case;

    state_debug := debug_in_data(11 downto 10);
  end process;
end RTL;
