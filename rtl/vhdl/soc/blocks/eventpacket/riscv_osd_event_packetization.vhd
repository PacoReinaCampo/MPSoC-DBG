-- Converted from rtl/verilog/blocks/eventpacket/riscv_osd_event_packetization.sv
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
use ieee.math_real.all;

use work.riscv_mpsoc_pkg.all;

entity riscv_osd_event_packetization is
  generic (
    XLEN       : integer := 64;
    DATA_WIDTH : integer := 64;

    MAX_DATA_NUM_WORDS : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    debug_out_data  : out std_logic_vector(XLEN-1 downto 0);
    debug_out_last  : out std_logic;
    debug_out_valid : out std_logic;
    debug_out_ready : in  std_logic;

    -- DI address of this module (SRC)
    id : in std_logic_vector(XLEN-1 downto 0);

    -- DI address of the event destination (DEST)
    dest     : in std_logic_vector(XLEN-1 downto 0);
    -- Generate an overflow packet
    overflow : in std_logic;

    -- a new event is available
    event_available : in  std_logic;
    -- the packet has been sent
    event_consumed  : out std_logic;

    -- number of data words this event consists of
    data_num_words : in std_logic_vector(integer(log2(real(MAX_DATA_NUM_WORDS)))-1 downto 0);

    -- data request: index of the data word
    data_req_idx   : out std_logic_vector(integer(log2(real(MAX_DATA_NUM_WORDS)))-1 downto 0);
    -- data request: request is valid
    data_req_valid : out std_logic;

    -- a data word
    data : in std_logic_vector(XLEN-1 downto 0)
  );
end riscv_osd_event_packetization;

architecture RTL of riscv_osd_event_packetization is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  constant NUM_HEADER_FLITS : integer := 1;  -- header flits: SRC, DEST, FLAGS
  constant MAX_PAYLOAD_LEN  : integer := MAX_PKT_LEN-NUM_HEADER_FLITS;

  -- packet counter within a single event transfer
  constant PKG_CNT_WIDTH         : integer := integer(log2(real((MAX_DATA_NUM_WORDS+(MAX_PAYLOAD_LEN-1))/MAX_PAYLOAD_LEN)));
  constant PKG_CNT_WIDTH_NONZERO : integer := PKG_CNT_WIDTH;

  -- number of packets required to transfer the event data
  -- cnt from 0..(num_pkgs-1) => num_pkgs requires one more bit
  constant NUM_PKGS_WIDTH : integer := PKG_CNT_WIDTH+1;

  -- FSM states
  constant IDLE_DEST   : std_logic_vector(2 downto 0) := "000";
  constant DESTINATION : std_logic_vector(2 downto 0) := "001";
  constant SOURCE      : std_logic_vector(2 downto 0) := "010";
  constant FLAGS       : std_logic_vector(2 downto 0) := "011";
  constant OVERFLOWS   : std_logic_vector(2 downto 0) := "100";
  constant PAYLOAD     : std_logic_vector(2 downto 0) := "101";

  constant TYPE_SUB_LAST     : std_logic_vector(3 downto 0) := X"0";
  constant TYPE_SUB_CONTINUE : std_logic_vector(3 downto 0) := X"1";
  constant TYPE_SUB_OVERFLOW : std_logic_vector(3 downto 0) := X"5";

  constant PAYLOAD_FLIT : integer := integer(log2(real(MAX_PAYLOAD_LEN)));
  constant NUM_WORDS    : integer := integer(log2(real(MAX_DATA_NUM_WORDS)));

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- packet counter within a single event transfer
  signal pkg_cnt     : std_logic_vector(PKG_CNT_WIDTH_NONZERO-1 downto 0);
  signal nxt_pkg_cnt : std_logic_vector(PKG_CNT_WIDTH_NONZERO-1 downto 0);

  -- number of packets required to transfer the event data
  -- cnt from 0..(num_pkgs-1) => num_pkgs requires one more bit
  signal num_pkgs : std_logic_vector(NUM_PKGS_WIDTH-1 downto 0);

  -- data word of event data
  signal word_cnt     : std_logic_vector(NUM_WORDS-1 downto 0);
  signal nxt_word_cnt : std_logic_vector(NUM_WORDS-1 downto 0);

  -- payload flit within the currently sent packet
  signal payload_flit_cnt     : std_logic_vector(PAYLOAD_FLIT-1 downto 0);
  signal nxt_payload_flit_cnt : std_logic_vector(PAYLOAD_FLIT-1 downto 0);

  -- FSM states
  signal state     : std_logic_vector(2 downto 0);
  signal nxt_state : std_logic_vector(2 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  -- number of packets required to transfer the event data
  -- cnt from 0..(num_pkgs-1) => num_pkgs requires one more bit
  num_pkgs <= std_logic_vector(to_unsigned((to_integer(unsigned(data_num_words))+MAX_PAYLOAD_LEN-1)/MAX_PAYLOAD_LEN, NUM_PKGS_WIDTH));

  data_req_idx   <= word_cnt;
  data_req_valid <= to_stdlogic(state = PAYLOAD) or to_stdlogic(state = OVERFLOWS);

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        word_cnt         <= (others => '0');
        payload_flit_cnt <= (others => '0');
        pkg_cnt          <= (others => '0');
        state            <= IDLE_DEST;
      else
        word_cnt         <= nxt_word_cnt;
        payload_flit_cnt <= nxt_payload_flit_cnt;
        pkg_cnt          <= nxt_pkg_cnt;
        state            <= nxt_state;
      end if;
    end if;
  end process;

  processing_1 : process (data, data_num_words, debug_out_ready, dest, event_available, id, num_pkgs, overflow, payload_flit_cnt, pkg_cnt, state, word_cnt)
  begin
    event_consumed       <= '0';
    debug_out_valid      <= '0';
    debug_out_data       <= (others => 'X');
    debug_out_last       <= '0';
    nxt_state            <= state;
    nxt_word_cnt         <= word_cnt;
    nxt_payload_flit_cnt <= payload_flit_cnt;
    nxt_pkg_cnt          <= pkg_cnt;

    case (state) is
      when IDLE_DEST =>
        debug_out_data <= (others => '0');
        if (event_available = '1') then
          debug_out_valid      <= '1';
          debug_out_data       <= dest;
          nxt_payload_flit_cnt <= (others => '0');
          if (debug_out_ready = '1') then
            nxt_state <= SOURCE;
          end if;
        end if;
      when SOURCE =>
        debug_out_valid <= '1';
        debug_out_data  <= id;
        if (debug_out_ready = '1') then
          nxt_state <= FLAGS;
        end if;
      when FLAGS =>
        -- TYPE == EVENT
        debug_out_data(15 downto 14) <= "10";
        -- TYPE_SUB
        if (overflow = '1') then
          debug_out_data(13 downto 10) <= TYPE_SUB_OVERFLOW;
        elsif (pkg_cnt = std_logic_vector(unsigned(num_pkgs)-to_unsigned(1, NUM_PKGS_WIDTH))) then
          debug_out_data(13 downto 10) <= TYPE_SUB_LAST;
        else
          debug_out_data(13 downto 10) <= TYPE_SUB_CONTINUE;
        end if;
        debug_out_data(9 downto 0) <= (others => '0');  -- reserved
        debug_out_valid            <= '1';
        if (debug_out_ready = '1') then
          if (overflow = '1') then
            nxt_state <= OVERFLOWS;
          else
            nxt_state <= PAYLOAD;
          end if;
        end if;
      when OVERFLOWS =>
        debug_out_valid <= '1';
        debug_out_data  <= data;
        debug_out_last  <= '1';
        if (debug_out_ready = '1') then
          nxt_state      <= IDLE_DEST;
          event_consumed <= '1';
        end if;
      when PAYLOAD =>
        debug_out_valid <= '1';
        if (word_cnt < std_logic_vector(unsigned(data_num_words)-to_unsigned(1, integer(log2(real(MAX_DATA_NUM_WORDS)))))) then
          debug_out_data <= data;
          debug_out_last <= to_stdlogic(unsigned(payload_flit_cnt) = to_unsigned(MAX_PAYLOAD_LEN-1, PAYLOAD_FLIT));
          if (debug_out_ready = '1') then
            nxt_word_cnt <= std_logic_vector(unsigned(word_cnt)+to_unsigned(1, NUM_WORDS));
            if (payload_flit_cnt = std_logic_vector(to_unsigned(MAX_PAYLOAD_LEN-1, PAYLOAD_FLIT))) then
              -- we need to continue the transfer in the next packet
              nxt_state            <= IDLE_DEST;
              nxt_pkg_cnt          <= std_logic_vector(unsigned(pkg_cnt)+to_unsigned(1, PKG_CNT_WIDTH_NONZERO));
              nxt_payload_flit_cnt <= (others => '0');
            else
              nxt_state            <= PAYLOAD;
              nxt_payload_flit_cnt <= std_logic_vector(unsigned(payload_flit_cnt)+to_unsigned(1, PAYLOAD_FLIT));
            end if;
          end if;
        else
          -- last payload word of the transfer
          debug_out_last <= '1';
          debug_out_data <= data;
          if (debug_out_ready = '1') then
            event_consumed <= '1';
            nxt_state      <= IDLE_DEST;
            nxt_pkg_cnt    <= (others => '0');
            nxt_word_cnt   <= (others => '0');
          end if;
        end if;
      when others =>
        null;
    end case;
  end process;
end RTL;
