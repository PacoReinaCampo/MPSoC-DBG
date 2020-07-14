-- Converted from rtl/verilog/interconnect/riscv_ring_router_demux.sv
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

entity riscv_ring_router_demux is
  generic (
    XLEN : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    id : in std_logic_vector(XLEN-1 downto 0);

    in_ring_data  : in  std_logic_vector(XLEN-1 downto 0);
    in_ring_last  : in  std_logic;
    in_ring_valid : in  std_logic;
    in_ring_ready : out std_logic;

    out_local_data  : out std_logic_vector(XLEN-1 downto 0);
    out_local_last  : out std_logic;
    out_local_valid : out std_logic;
    out_local_ready : in  std_logic;

    out_ring_data  : out std_logic_vector(XLEN-1 downto 0);
    out_ring_last  : out std_logic;
    out_ring_valid : out std_logic;
    out_ring_ready : in  std_logic
    );
end riscv_ring_router_demux;

architecture RTL of riscv_ring_router_demux is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal worm       : std_logic;
  signal worm_local : std_logic;

  signal is_local : std_logic;

  signal switch_local : std_logic;

  signal in_ring_ready_sgn : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  out_local_data <= in_ring_data;
  out_local_last <= in_ring_last;
  out_ring_data  <= in_ring_data;
  out_ring_last  <= in_ring_last;

  is_local <= to_stdlogic(in_ring_data = id);

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        worm       <= '0';
        worm_local <= 'X';
      elsif (worm = '0') then
        worm_local <= is_local;
        if (in_ring_ready_sgn = '1' and in_ring_valid = '1' and in_ring_last = '0') then
          worm <= '1';
        end if;
      elsif (in_ring_ready_sgn = '1' and in_ring_valid = '1' and in_ring_last = '1') then
        worm <= '0';
      end if;
    end if;
  end process;

  switch_local <= worm_local
                  when worm = '1' else is_local;

  out_ring_valid  <= not switch_local and in_ring_valid;
  out_local_valid <= switch_local and in_ring_valid;

  in_ring_ready_sgn <= out_local_ready
                       when switch_local = '1' else out_ring_ready;

  in_ring_ready <= in_ring_ready_sgn;
end RTL;
