-- Converted from rtl/verilog/blocks/tracesample/riscv_osd_tracesample.sv
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
--              Debug Interface                                               //
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
-- *   Francisco Javier Reina Campo <frareicam@gmail.com>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.riscv_dbg_pkg.all;

entity riscv_osd_tracesample is
  generic (
    WIDTH : integer := 64
  );
  port (
    clk          : in std_ulogic;
    rst          : in std_ulogic;
    sample_data  : in std_ulogic_vector(WIDTH-1 downto 0);
    sample_valid : in std_ulogic;

    fifo_data     : out std_ulogic_vector(WIDTH-1 downto 0);
    fifo_overflow : out std_ulogic;
    fifo_valid    : out std_ulogic;
    fifo_ready    : in  std_ulogic
    );
end riscv_osd_tracesample;

architecture RTL of riscv_osd_tracesample is
  --////////////////////////////////////////////////////////////////
  --
  -- Functions
  --
  function reduce_and (
    reduce_and_in : std_ulogic_vector
    ) return std_ulogic is
    variable reduce_and_out : std_ulogic := '0';
  begin
    for i in reduce_and_in'range loop
      reduce_and_out := reduce_and_out and reduce_and_in(i);
    end loop;
    return reduce_and_out;
  end reduce_and;

  function to_stdlogic (
    input : boolean
    ) return std_ulogic is
  begin
    if input then
      return('1');
    else
      return('0');
    end if;
  end function to_stdlogic;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal ov_counter : std_ulogic_vector(15 downto 0);

  signal passthrough : std_ulogic;

  signal ov_increment : std_ulogic;
  signal ov_saturate  : std_ulogic;
  signal ov_complete  : std_ulogic;
  signal ov_again     : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  passthrough <= to_stdlogic(ov_counter = std_ulogic_vector(to_unsigned(0, 16)));

  fifo_data(15 downto 0) <= sample_data(15 downto 0)
                            when passthrough = '1' else ov_counter;

  generating_0 : if (WIDTH > 16) generate
    fifo_data(WIDTH-1 downto 16) <= sample_data(WIDTH-1 downto 16);
  end generate;


  fifo_overflow <= not passthrough;
  fifo_valid    <= sample_valid
                when passthrough = '1' else '1';

  ov_increment <= (sample_valid and not fifo_ready);
  ov_saturate  <= reduce_and(ov_counter);
  ov_complete  <= not passthrough and fifo_ready and not sample_valid;
  ov_again     <= not passthrough and fifo_ready and sample_valid;

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1' or ov_complete = '1') then
        ov_counter <= std_ulogic_vector(to_unsigned(0, 16));
      elsif (ov_again = '1') then
        ov_counter <= std_ulogic_vector(to_unsigned(1, 16));
      elsif (ov_increment = '1' and ov_saturate = '0') then
        ov_counter <= std_ulogic_vector(unsigned(ov_counter)-to_unsigned(1, 16));
      end if;
    end if;
  end process;
end RTL;
