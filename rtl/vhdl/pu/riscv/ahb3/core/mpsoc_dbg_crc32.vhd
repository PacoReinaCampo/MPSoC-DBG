-- Converted from rtl/verilog/core/mpsoc_dbg_crc32.sv
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
--              WishBone Bus Interface                                        //
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

entity mpsoc_dbg_crc32 is
  port (
    rstn       : in  std_logic;
    clk        : in  std_logic;
    data       : in  std_logic;
    enable     : in  std_logic;
    shift      : in  std_logic;
    clr        : in  std_logic;
    crc_out    : out std_logic_vector(31 downto 0);
    serial_out : out std_logic
    );
end mpsoc_dbg_crc32;

architecture RTL of mpsoc_dbg_crc32 is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal crc     : std_logic_vector(31 downto 0);
  signal new_crc : std_logic_vector(31 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- You may notice that the 'poly' in this implementation is backwards.
  -- This is because the shift is also 'backwards', so that the data can
  -- be shifted out in the same direction, which saves on logic + routing.
  new_crc(00) <= crc(01);
  new_crc(01) <= crc(02);
  new_crc(02) <= crc(03);
  new_crc(03) <= crc(04);
  new_crc(04) <= crc(05);
  new_crc(05) <= crc(06) xor data xor crc(0);
  new_crc(06) <= crc(07);
  new_crc(07) <= crc(08);
  new_crc(08) <= crc(09) xor data xor crc(0);
  new_crc(09) <= crc(10) xor data xor crc(0);
  new_crc(10) <= crc(11);
  new_crc(11) <= crc(12);
  new_crc(12) <= crc(13);
  new_crc(13) <= crc(14);
  new_crc(14) <= crc(15);
  new_crc(15) <= crc(16) xor data xor crc(0);
  new_crc(16) <= crc(17);
  new_crc(17) <= crc(18);
  new_crc(18) <= crc(19);
  new_crc(19) <= crc(20) xor data xor crc(0);
  new_crc(20) <= crc(21) xor data xor crc(0);
  new_crc(21) <= crc(22) xor data xor crc(0);
  new_crc(22) <= crc(23);
  new_crc(23) <= crc(24) xor data xor crc(0);
  new_crc(24) <= crc(25) xor data xor crc(0);
  new_crc(25) <= crc(26);
  new_crc(26) <= crc(27) xor data xor crc(0);
  new_crc(27) <= crc(28) xor data xor crc(0);
  new_crc(28) <= crc(29);
  new_crc(29) <= crc(30) xor data xor crc(0);
  new_crc(30) <= crc(31) xor data xor crc(0);
  new_crc(31) <= data xor crc(0);

  processing_0 : process (clk, rstn)
  begin
    if (rstn = '0') then
      crc(31 downto 0) <= X"ffffffff";
    elsif (rising_edge(clk)) then
      if (clr = '1') then
        crc(31 downto 0) <= X"ffffffff";
      elsif (enable = '1') then
        crc(31 downto 0) <= new_crc;
      elsif (shift = '1') then
        crc(31 downto 0) <= ('0' & crc(31 downto 1));
      end if;
    end if;
  end process;

  --assign crc_match = (crc == 32'h0);
  crc_out    <= crc;  --[31];
  serial_out <= crc(0);
end RTL;
