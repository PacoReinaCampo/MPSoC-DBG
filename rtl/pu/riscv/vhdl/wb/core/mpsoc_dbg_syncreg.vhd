-- Converted from rtl/verilog/core/mpsoc_dbg_syncreg.sv
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

-- Top module
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_syncreg is
  port (
    CLKA     : in  std_logic;
    CLKB     : in  std_logic;
    RST      : in  std_logic;
    DATA_IN  : in  std_logic_vector(3 downto 0);
    DATA_OUT : out std_logic_vector(3 downto 0)
    );
end mpsoc_dbg_syncreg;

architecture RTL of mpsoc_dbg_syncreg is
  component mpsoc_dbg_syncflop
    port (
      DEST_CLK  : in  std_logic;
      D_SET     : in  std_logic;
      D_RST     : in  std_logic;
      RESET     : in  std_logic;
      TOGGLE_IN : in  std_logic;
      D_OUT     : out std_logic
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal regA          : std_logic_vector(3 downto 0);
  signal regB          : std_logic_vector(3 downto 0);
  signal strobe_toggle : std_logic;
  signal ack_toggle    : std_logic;

  signal a_not_equal    : std_logic;
  signal a_enable       : std_logic;
  signal strobe_sff_out : std_logic;
  signal ack_sff_out    : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Combinatorial assignments
  a_enable    <= a_not_equal and ack_sff_out;
  a_not_equal <= not to_stdlogic(DATA_IN = regA);
  DATA_OUT    <= regB;

  -- register A (latches input any time it changes)
  processing_0 : process (CLKA, RST)
  begin
    if (RST = '1') then
      regA <= "0000";
    elsif (rising_edge(CLKA)) then
      if (a_enable = '1') then
        regA <= DATA_IN;
      end if;
    end if;
  end process;

  -- register B (latches data from regA when enabled by the strobe SFF)
  processing_1 : process (CLKB, RST)
  begin
    if (RST = '1') then
      regB <= "0000";
    elsif (rising_edge(CLKB)) then
      if (strobe_sff_out = '1') then
        regB <= regA;
      end if;
    end if;
  end process;

  -- 'strobe' toggle FF
  processing_2 : process (CLKA, RST)
  begin
    if (RST = '1') then
      strobe_toggle <= '0';
    elsif (rising_edge(CLKA)) then
      if (a_enable = '1') then
        strobe_toggle <= not strobe_toggle;
      end if;
    end if;
  end process;

  -- 'ack' toggle FF
  -- This is set to '1' at reset, to initialize the unit.
  processing_3 : process (CLKB, RST)
  begin
    if (RST = '1') then
      ack_toggle <= '1';
    elsif (rising_edge(CLKB)) then
      if (strobe_sff_out = '1') then
        ack_toggle <= not ack_toggle;
      end if;
    end if;
  end process;

  -- 'strobe' sync element
  strobe_sff : mpsoc_dbg_syncflop
    port map (
      DEST_CLK  => CLKB,
      D_SET     => '0',
      D_RST     => strobe_sff_out,
      RESET     => RST,
      TOGGLE_IN => strobe_toggle,
      D_OUT     => strobe_sff_out
      );

  -- 'ack' sync element
  ack_sff : mpsoc_dbg_syncflop
    port map (
      DEST_CLK  => CLKA,
      D_SET     => '0',
      D_RST     => a_enable,
      RESET     => RST,
      TOGGLE_IN => ack_toggle,
      D_OUT     => ack_sff_out
      );
end RTL;
