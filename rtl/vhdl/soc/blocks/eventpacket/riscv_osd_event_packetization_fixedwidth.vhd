-- Converted from rtl/verilog/blocks/eventpacket/riscv_osd_event_packetization_fixedwidth.sv
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

use work.riscv_dbg_pkg.all;

entity riscv_osd_event_packetization_fixedwidth is
  generic (
    XLEN       : integer := 64;
    DATA_WIDTH : integer := 64
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

    data : in std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end riscv_osd_event_packetization_fixedwidth;

architecture RTL of riscv_osd_event_packetization_fixedwidth is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant LOG2_NUM_WORDS : integer := integer(log2(real(MAX_DATA_NUM_WORDS)));

  constant VECTOR_DATA_NUM_WORDS : std_logic_vector(LOG2_NUM_WORDS-1 downto 0) := std_logic_vector(to_unsigned(MAX_DATA_NUM_WORDS, LOG2_NUM_WORDS));

  component riscv_osd_event_packetization
    generic (
      XLEN       : integer := 64;
      DATA_WIDTH : integer := 64
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      debug_out_data  : out std_logic_vector(XLEN-1 downto 0);
      debug_out_last  : out std_logic;
      debug_out_valid : out std_logic;
      debug_out_ready : in  std_logic;

      id : in std_logic_vector(XLEN-1 downto 0);

      dest     : in std_logic_vector(XLEN-1 downto 0);
      overflow : in std_logic;

      event_available : in  std_logic;
      event_consumed  : out std_logic;

      data_num_words : in std_logic_vector(LOG2_NUM_WORDS-1 downto 0);

      data_req_idx : out std_logic_vector(LOG2_NUM_WORDS-1 downto 0);

      data_req_valid : out std_logic;

      data : in std_logic_vector(XLEN-1 downto 0)
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal data_req_idx : std_logic_vector(LOG2_NUM_WORDS-1 downto 0);
  signal data_word    : std_logic_vector(XLEN-1 downto 0);

  -- number of bits to fill in the last word
  signal fill_last : std_logic_vector(3 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  fill_last <= std_logic_vector(to_unsigned(XLEN-DATA_WIDTH mod XLEN, 4));

  processing_0 : process (data, data_req_idx, fill_last)
  begin
    if (data_req_idx < std_logic_vector(to_unsigned(MAX_DATA_NUM_WORDS-1, LOG2_NUM_WORDS))) then
      --data_word <= data(XLEN downto (to_integer(unsigned(data_req_idx))+1)*XLEN-1);
    elsif (unsigned(data_req_idx) = to_unsigned(MAX_DATA_NUM_WORDS-1, LOG2_NUM_WORDS)) then
      -- last word must be padded with 0s if the data doesn't fill a word
      for i in 0 to XLEN-1 loop
        if (i < to_integer(unsigned(fill_last))) then
          data_word(XLEN-i-1) <= '0';
        else
          data_word(XLEN-i-1) <= data(DATA_WIDTH-1-(i-to_integer(unsigned(fill_last))));
        end if;
      end loop;
    else
      data_word <= (others => '0');
    end if;
  end process;

  osd_event_packetization : riscv_osd_event_packetization
    generic map (
      XLEN       => XLEN,
      DATA_WIDTH => DATA_WIDTH
    )
    port map (
      clk => clk,
      rst => rst,

      debug_out_data  => debug_out_data,
      debug_out_last  => debug_out_last,
      debug_out_valid => debug_out_valid,
      debug_out_ready => debug_out_ready,

      id              => id,
      dest            => dest,
      overflow        => overflow,
      event_available => event_available,
      event_consumed  => event_consumed,

      data_num_words => VECTOR_DATA_NUM_WORDS(LOG2_NUM_WORDS-1 downto 0),
      data_req_valid => open,
      data_req_idx   => data_req_idx,

      data => data_word
    );
end RTL;
