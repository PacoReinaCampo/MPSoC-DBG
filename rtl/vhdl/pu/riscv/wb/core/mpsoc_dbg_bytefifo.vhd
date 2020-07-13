-- Converted from rtl/verilog/core/mpsoc_dbg_bytefifo.sv
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

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_bytefifo is
  port (
    CLK         : in  std_logic;
    RST         : in  std_logic;
    DATA_IN     : in  std_logic_vector(7 downto 0);
    DATA_OUT    : out std_logic_vector(7 downto 0);
    PUSH_POPn   : in  std_logic;
    EN          : in  std_logic;
    BYTES_AVAIL : out std_logic_vector(3 downto 0);
    BYTES_FREE  : out std_logic_vector(3 downto 0)
    );
end mpsoc_dbg_bytefifo;

architecture RTL of mpsoc_dbg_bytefifo is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal reg0 : std_logic_vector(7 downto 0);
  signal reg1 : std_logic_vector(7 downto 0);
  signal reg2 : std_logic_vector(7 downto 0);
  signal reg3 : std_logic_vector(7 downto 0);
  signal reg4 : std_logic_vector(7 downto 0);
  signal reg5 : std_logic_vector(7 downto 0);
  signal reg6 : std_logic_vector(7 downto 0);
  signal reg7 : std_logic_vector(7 downto 0);

  signal counter : std_logic_vector(3 downto 0);

  signal push_ok : std_logic;
  signal pop_ok  : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Combinatorial assignments
  BYTES_AVAIL <= counter;
  BYTES_FREE  <= std_logic_vector(X"8"-unsigned(counter));
  push_ok     <= not to_stdlogic(counter = X"8");
  pop_ok      <= not to_stdlogic(counter = X"0");

  -- FIFO memory / shift registers

  -- Reg 0 - takes input from DATA_IN
  processing_0 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg0 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg0 <= DATA_IN;
      end if;
    end if;
  end process;

  -- Reg 1 - takes input from reg0
  processing_1 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg1 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg1 <= reg0;
      end if;
    end if;
  end process;

  -- Reg 2 - takes input from reg1
  processing_2 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg2 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg2 <= reg1;
      end if;
    end if;
  end process;

  -- Reg 3 - takes input from reg2
  processing_3 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg3 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg3 <= reg2;
      end if;
    end if;
  end process;

  -- Reg 4 - takes input from reg3
  processing_4 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg4 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg4 <= reg3;
      end if;
    end if;
  end process;

  -- Reg 5 - takes input from reg4
  processing_5 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg5 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg5 <= reg4;
      end if;
    end if;
  end process;

  -- Reg 6 - takes input from reg5
  processing_6 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg6 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg6 <= reg5;
      end if;
    end if;
  end process;

  -- Reg 7 - takes input from reg6
  processing_7 : process (CLK, RST)
  begin
    if (RST = '1') then
      reg7 <= X"00";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        reg7 <= reg6;
      end if;
    end if;
  end process;

  -- Read counter
  -- This is a 4-bit saturating up/down counter
  -- The 'saturating' is done via push_ok and pop_ok
  processing_8 : process (CLK, RST)
  begin
    if (RST = '1') then
      counter <= X"0";
    elsif (rising_edge(CLK)) then
      if (EN = '1' and PUSH_POPn = '1' and push_ok = '1') then
        counter <= std_logic_vector(unsigned(counter)+X"1");
      elsif (EN = '1' and PUSH_POPn = '0' and pop_ok = '1') then
        counter <= std_logic_vector(unsigned(counter)-X"1");
      end if;
    end if;
  end process;

  -- Output decoder
  processing_9 : process (counter, reg0, reg1, reg2, reg3, reg4, reg5, reg6, reg7)
  begin
    case (counter) is
      when X"1" =>
        DATA_OUT <= reg0;
      when X"2" =>
        DATA_OUT <= reg1;
      when X"3" =>
        DATA_OUT <= reg2;
      when X"4" =>
        DATA_OUT <= reg3;
      when X"5" =>
        DATA_OUT <= reg4;
      when X"6" =>
        DATA_OUT <= reg5;
      when X"7" =>
        DATA_OUT <= reg6;
      when X"8" =>
        DATA_OUT <= reg7;
      when others =>
        DATA_OUT <= "XXXXXXXX";
    end case;
  end process;
end RTL;
