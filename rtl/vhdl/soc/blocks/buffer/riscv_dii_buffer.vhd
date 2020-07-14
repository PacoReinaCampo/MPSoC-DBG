-- Converted from rtl/verilog/blocks/buffer/riscv_dii_buffer.sv
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
use work.riscv_dbg_pkg.all;

entity riscv_dii_buffer is
  generic (
    XLEN        : integer := 64;
    BUFFER_SIZE : integer := 4;
    FULLPACKET  : std_logic := '0'
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    packet_size : out std_logic_vector(integer(log2(real(BUFFER_SIZE))) downto 0);

    flit_in_data  : in  std_logic_vector(XLEN-1 downto 0);
    flit_in_last  : in  std_logic;
    flit_in_valid : in  std_logic;
    flit_in_ready : out std_logic;

    flit_out_data  : out std_logic_vector(XLEN-1 downto 0);
    flit_out_last  : out std_logic;
    flit_out_valid : out std_logic;
    flit_out_ready : in  std_logic
  );
end riscv_dii_buffer;

architecture RTL of riscv_dii_buffer is
  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function find_first_one (
    data : std_logic_vector(BUFFER_SIZE-1 downto 0)
  ) return std_logic_vector is
    variable find_first_one_return : std_logic_vector (LOG2_BUFFER_SIZE downto 0);
  begin
    for i in BUFFER_SIZE downto 0 loop
      if (data(i) = '1') then
        find_first_one_return := std_logic_vector(to_unsigned(i, LOG2_BUFFER_SIZE));
      end if;
    end loop;
    return find_first_one_return;
  end find_first_one;  -- size_count

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- internal shift register
  signal data_data  : std_logic_matrix(BUFFER_SIZE-1 downto 0)(XLEN-1 downto 0);
  signal data_last  : std_logic_vector(BUFFER_SIZE-1 downto 0);
  signal data_valid : std_logic_vector(BUFFER_SIZE-1 downto 0);

  signal rp            : std_logic_vector(LOG2_BUFFER_SIZE downto 0);  -- read pointer
  signal reg_out_valid : std_logic;  -- local output valid
  signal flit_in_fire  : std_logic;
  signal flit_out_fire : std_logic;

  signal data_last_buf     : std_logic_vector(BUFFER_SIZE-1 downto 0);
  signal data_last_shifted : std_logic_vector(BUFFER_SIZE-1 downto 0);

  signal flit_in_ready_sgn  : std_logic;
  signal flit_out_valid_sgn : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  flit_in_ready_sgn <= to_stdlogic(rp /= std_logic_vector(to_unsigned(BUFFER_SIZE-1, LOG2_BUFFER_SIZE))) or not reg_out_valid;
  flit_in_fire      <= flit_in_valid and flit_in_ready_sgn;
  flit_out_fire     <= flit_out_valid_sgn and flit_out_ready;

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        reg_out_valid <= '0';
      elsif (flit_in_valid = '1') then
        reg_out_valid <= '1';
      elsif (flit_out_fire = '1' and rp = std_logic_vector(to_unsigned(0, LOG2_BUFFER_SIZE))) then
        reg_out_valid <= '0';
      end if;
    end if;
  end process;

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        rp <= std_logic_vector(to_unsigned(1, LOG2_BUFFER_SIZE+1));
      elsif (flit_in_fire = '1' and flit_out_fire = '0' and reg_out_valid = '1') then
        rp <= std_logic_vector(unsigned(rp)+to_unsigned(1, LOG2_BUFFER_SIZE));
      elsif (flit_out_fire = '1' and flit_in_fire = '0' and rp /= std_logic_vector(to_unsigned(0, LOG2_BUFFER_SIZE))) then
        rp <= std_logic_vector(unsigned(rp)-to_unsigned(1, LOG2_BUFFER_SIZE));
      end if;
    end if;
  end process;

  processing_2 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (flit_in_fire = '1') then
        data_data  <= (data_data(BUFFER_SIZE-1 downto 1) & flit_in_data);
        data_last  <= (data_last(BUFFER_SIZE-1 downto 1) & flit_in_last);
        data_valid <= (data_valid(BUFFER_SIZE-1 downto 1) & flit_in_valid);
      end if;
    end if;
  end process;

  -- SRL does not allow parallel read
  generating_0 : if (FULLPACKET = '1') generate
    processing_3 : process (clk)
    begin
      if (rising_edge(clk)) then
        if (rst = '1') then
          data_last_buf <= (others => '0');
        elsif (flit_in_fire = '1') then
          data_last_buf <= data_last_buf & (flit_in_last and flit_in_valid);
        end if;
      end if;
    end process;
    -- extra logic to get the packet size in a stable manner
    data_last_shifted <= std_logic_vector(unsigned(data_last_buf) sll (BUFFER_SIZE-1-to_integer(unsigned(rp))));

    packet_size <= std_logic_vector(unsigned(to_unsigned(BUFFER_SIZE, LOG2_BUFFER_SIZE)-unsigned(find_first_one(data_last_shifted))));

    processing_4 : process(data_data, data_last, data_last_shifted, reg_out_valid, rp)
    begin
      flit_out_data      <= data_data(to_integer(unsigned(rp)));
      flit_out_last      <= data_last(to_integer(unsigned(rp)));
      flit_out_valid_sgn <= reg_out_valid and reduce_or(data_last_shifted);
    end process;
  elsif (FULLPACKET = '0') generate
    packet_size <= (others => '0');

    processing_5 : process (data_data, data_last, reg_out_valid, rp)
    begin
      flit_out_data      <= data_data(to_integer(unsigned(rp)));
      flit_out_last      <= data_last(to_integer(unsigned(rp)));
      flit_out_valid_sgn <= reg_out_valid;
    end process;
  end generate;

  flit_in_ready  <= flit_in_ready_sgn;
  flit_out_valid <= flit_out_valid_sgn;
end RTL;
