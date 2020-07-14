-- Converted from rtl/verilog/blocks/buffer/riscv_osd_fifo.sv
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

entity riscv_osd_fifo is
  generic (
    WIDTH : integer := 64;
    DEPTH : integer := 8
  );
  port (
    clk : in std_ulogic;
    rst : in std_ulogic;

    in_data  : in  std_ulogic_vector(WIDTH-1 downto 0);
    in_valid : in  std_ulogic;
    in_ready : out std_ulogic;

    out_data  : out std_ulogic_vector(WIDTH-1 downto 0);
    out_valid : out std_ulogic;
    out_ready : in  std_ulogic
    );
end riscv_osd_fifo;

architecture RTL of riscv_osd_fifo is

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Signals for fifo
  signal fifo_data     : std_logic_matrix(DEPTH-1 downto 0)(WIDTH-1 downto 0);  --actual fifo
  signal nxt_fifo_data : std_logic_matrix(DEPTH-1 downto 0)(WIDTH-1 downto 0);

  signal fifo_write_ptr : std_ulogic_vector(DEPTH downto 0);

  signal pop  : std_ulogic;
  signal push : std_ulogic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  pop  <= not fifo_write_ptr(0) and out_ready;
  push <= in_valid and not fifo_write_ptr(DEPTH);

  out_data  <= fifo_data(0);
  out_valid <= not fifo_write_ptr(0);

  in_ready <= not fifo_write_ptr(DEPTH);

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        fifo_write_ptr <= std_ulogic_vector(to_unsigned(1, DEPTH+1));
      elsif (push = '1' and pop = '0') then
        fifo_write_ptr <= std_ulogic_vector(unsigned(fifo_write_ptr) sll 1);
      elsif (push = '0' and pop = '1') then
        fifo_write_ptr <= std_ulogic_vector(unsigned(fifo_write_ptr) srl 1);
      end if;
    end if;
  end process;

  processing_1 : process(pop, push, fifo_write_ptr, fifo_data, in_data)
  begin
    for i in 0 to DEPTH - 1 loop
      if (pop = '1') then
        if (push = '1' and fifo_write_ptr(i+1) = '1') then
          nxt_fifo_data(i) <= in_data;
        elsif (i < DEPTH-1) then
          nxt_fifo_data(i) <= fifo_data(i+1);
        else
          nxt_fifo_data(i) <= fifo_data(i);
        end if;
      elsif (push = '1' and fifo_write_ptr(i) = '1') then
        nxt_fifo_data(i) <= in_data;
      else
        nxt_fifo_data(i) <= fifo_data(i);
      end if;
    end loop;
  end process;

  processing_2 : process (clk)
  begin
    if (rising_edge(clk)) then
      for i in 0 to DEPTH - 1 loop
        fifo_data(i) <= nxt_fifo_data(i);
      end loop;
    end if;
  end process;
end RTL;
