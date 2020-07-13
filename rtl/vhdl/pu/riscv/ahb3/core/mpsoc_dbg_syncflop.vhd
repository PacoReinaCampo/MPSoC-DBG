-- Converted from rtl/verilog/core/mpsoc_dbg_syncflop.sv
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
-- *   Nathan Yawn <nathan.yawn@opencores.org>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpsoc_dbg_syncflop is
  port (
    RESET : in std_logic;  -- asynchronous reset

    DEST_CLK  : in  std_logic;  -- destination clock domain clock
    D_SET     : in  std_logic;  -- synchronously set output to '1' (synchronous to dest.clock domain)
    D_RST     : in  std_logic;  -- synchronously reset output to '0' (synch. to dest.clock domain)
    TOGGLE_IN : in  std_logic;  -- toggle data from source clock domain
    D_OUT     : out std_logic   -- output (synch. to dest.clock domain)
    );
end mpsoc_dbg_syncflop;

architecture RTL of mpsoc_dbg_syncflop is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal sync1 : std_logic;
  signal sync2 : std_logic;

  signal syncprev : std_logic;

  signal srflop : std_logic;

  -- Combinatorial assignments
  signal toggle  : std_logic;
  signal srinput : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Synchronise toggle signal to destination clock domain

  -- First synchronisation stage
  processing_0 : process (DEST_CLK, RESET)
  begin
    if (RESET = '1') then
      sync1 <= '0';
    elsif (rising_edge(DEST_CLK)) then
      sync1 <= TOGGLE_IN;
    end if;
  end process;

  -- Second synchronisation stage
  processing_1 : process (DEST_CLK, RESET)
  begin
    if (RESET = '1') then
      sync2 <= '0';
    elsif (rising_edge(DEST_CLK)) then
      sync2 <= sync1;
    end if;
  end process;

  -- Detect toggle

  -- Previous synchronized value
  processing_2 : process (DEST_CLK, RESET)
  begin
    if (RESET = '1') then
      syncprev <= '0';
    elsif (rising_edge(DEST_CLK)) then
      syncprev <= sync2;
    end if;
  end process;

  toggle  <= sync2 xor syncprev;
  srinput <= toggle or D_SET;

  D_OUT <= toggle or srflop;

  -- Set/Reset FF (holds detected toggles)
  processing_3 : process (DEST_CLK, RESET)
  begin
    if (RESET = '1') then
      srflop <= '0';
    elsif (rising_edge(DEST_CLK)) then
      if (D_RST = '1') then
        srflop <= '0';
      elsif (srinput = '1') then
        srflop <= '1';
      end if;
    end if;
  end process;
end RTL;
