-- Converted from rtl/verilog/blocks/regaccess/riscv_osd_regaccess_demux.sv
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

entity riscv_osd_regaccess_demux is
  generic (
    XLEN : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    in_data  : in  std_logic_vector(XLEN-1 downto 0);
    in_last  : in  std_logic;
    in_valid : in  std_logic;
    in_ready : out std_logic;

    out_reg_data  : out std_logic_vector(XLEN-1 downto 0);
    out_reg_last  : out std_logic;
    out_reg_valid : out std_logic;
    out_reg_ready : in  std_logic;

    out_bypass_data  : out std_logic_vector(XLEN-1 downto 0);
    out_bypass_last  : out std_logic;
    out_bypass_valid : out std_logic;
    out_bypass_ready : in  std_logic
  );
end riscv_osd_regaccess_demux;

architecture RTL of riscv_osd_regaccess_demux is

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal buf_reg_data  : std_logic_matrix(2 downto 0)(XLEN-1 downto 0);
  signal buf_reg_last  : std_logic_vector(2 downto 0);
  signal buf_reg_valid : std_logic_vector(2 downto 0);

  signal buf_reg_is_regaccess : std_logic_vector(2 downto 0);
  signal buf_reg_is_bypass    : std_logic_vector(2 downto 0);

  signal do_tag, mark_bypass, mark_regaccess : std_logic;

  signal pkg_is_bypass, pkg_is_regaccess : std_logic;

  signal keep_1, keep_2 : std_logic;

  signal no_buf_entry_is_tagged : std_logic;

  signal in_ready_sgn : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  do_tag <= buf_reg_valid(2) and buf_reg_valid(1) and buf_reg_valid(0) and (not buf_reg_is_regaccess(2) and not buf_reg_is_bypass(2)) and (not buf_reg_is_regaccess(1) and not buf_reg_is_bypass(1)) and (not buf_reg_is_regaccess(0) and not buf_reg_is_bypass(0));

  mark_bypass    <= do_tag and to_stdlogic(buf_reg_data(0)(15 downto 14) /= "00");
  mark_regaccess <= do_tag and to_stdlogic(buf_reg_data(0)(15 downto 14) = "00");

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        pkg_is_bypass    <= '0';
        pkg_is_regaccess <= '0';
      else
        pkg_is_bypass    <= (pkg_is_bypass or mark_bypass) and not (in_last and in_valid and in_ready_sgn) and not (buf_reg_last(0) and buf_reg_valid(0));
        pkg_is_regaccess <= (pkg_is_regaccess or mark_regaccess) and not (in_last and in_valid and in_ready_sgn) and not (buf_reg_last(0) and buf_reg_valid(0));
      end if;
    end if;
  end process;

  keep_1 <= not do_tag and buf_reg_valid(1) and not (buf_reg_is_bypass(1) or buf_reg_is_regaccess(1)) and keep_2;
  keep_2 <= not do_tag and buf_reg_valid(2) and not (buf_reg_is_bypass(2) or buf_reg_is_regaccess(2));

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        buf_reg_valid(0)        <= '0';
        buf_reg_is_regaccess(0) <= '0';
        buf_reg_is_bypass(0)    <= '0';

        buf_reg_valid(1)        <= '0';
        buf_reg_is_regaccess(1) <= '0';
        buf_reg_is_bypass(1)    <= '0';

        buf_reg_valid(2)        <= '0';
        buf_reg_is_regaccess(2) <= '0';
        buf_reg_is_bypass(2)    <= '0';
      elsif (in_ready_sgn = '1') then
        buf_reg_data(0)  <= in_data;
        buf_reg_last(0)  <= in_last;
        buf_reg_valid(0) <= in_valid and in_ready_sgn;
        if (buf_reg_valid(0) = '1' and buf_reg_last(0) = '0') then
          buf_reg_is_regaccess(0) <= pkg_is_regaccess or mark_regaccess;
          buf_reg_is_bypass(0)    <= pkg_is_bypass or mark_bypass;
        else
          buf_reg_is_regaccess(0) <= pkg_is_regaccess;
          buf_reg_is_bypass(0)    <= pkg_is_bypass;
        end if;
        if (keep_1 = '0') then
          buf_reg_data(1)         <= buf_reg_data(0);
          buf_reg_last(1)         <= buf_reg_last(0);
          buf_reg_valid(1)        <= buf_reg_valid(0);
          buf_reg_is_regaccess(1) <= buf_reg_is_regaccess(0) or mark_regaccess;
          buf_reg_is_bypass(1)    <= buf_reg_is_bypass(0) or mark_bypass;
        else
          buf_reg_is_regaccess(1) <= buf_reg_is_regaccess(1) or mark_regaccess;
          buf_reg_is_bypass(1)    <= buf_reg_is_bypass(1) or mark_bypass;
        end if;
        if (keep_2 = '0') then
          buf_reg_data(2)         <= buf_reg_data(1);
          buf_reg_last(2)         <= buf_reg_last(1);
          buf_reg_valid(2)        <= buf_reg_valid(1);
          buf_reg_is_regaccess(2) <= buf_reg_is_regaccess(1) or mark_regaccess;
          buf_reg_is_bypass(2)    <= buf_reg_is_bypass(1) or mark_bypass;
        else
          buf_reg_is_regaccess(2) <= buf_reg_is_regaccess(2) or mark_regaccess;
          buf_reg_is_bypass(2)    <= buf_reg_is_bypass(2) or mark_bypass;
        end if;
      end if;
    end if;
  end process;

  -- Output data
  out_reg_data  <= buf_reg_data(2);
  out_reg_last  <= buf_reg_last(2);
  out_reg_valid <= buf_reg_valid(2) and (buf_reg_is_regaccess(2) or mark_regaccess);

  out_bypass_data  <= buf_reg_data(2);
  out_bypass_last  <= buf_reg_last(2);
  out_bypass_valid <= buf_reg_valid(2) and (buf_reg_is_bypass(2) or mark_bypass);

  no_buf_entry_is_tagged <= not do_tag and not ((reduce_or(buf_reg_is_regaccess)) or reduce_or(buf_reg_is_bypass));

  in_ready_sgn <= (out_bypass_ready and out_reg_ready) or (out_bypass_ready and (buf_reg_is_bypass(2) or mark_bypass)) or (out_reg_ready and (buf_reg_is_regaccess(2) or mark_regaccess)) or no_buf_entry_is_tagged;

  in_ready <= in_ready_sgn;
end RTL;
