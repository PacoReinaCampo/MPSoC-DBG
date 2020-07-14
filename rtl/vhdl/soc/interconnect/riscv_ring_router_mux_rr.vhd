-- Converted from rtl/verilog/interconnect/riscv_ring_router_mux_rr.sv
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

entity riscv_ring_router_mux_rr is
  generic (
    XLEN : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    in0_data  : in  std_logic_vector(XLEN-1 downto 0);
    in0_last  : in  std_logic;
    in0_valid : in  std_logic;
    in0_ready : out std_logic;

    in1_data  : in  std_logic_vector(XLEN-1 downto 0);
    in1_last  : in  std_logic;
    in1_valid : in  std_logic;
    in1_ready : out std_logic;

    out_mux_data  : out std_logic_vector(XLEN-1 downto 0);
    out_mux_last  : out std_logic;
    out_mux_valid : out std_logic;
    out_mux_ready : in  std_logic
    );
end riscv_ring_router_mux_rr;

architecture RTL of riscv_ring_router_mux_rr is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant NOWORM0 : std_logic_vector(1 downto 0) := "00";
  constant NOWORM1 : std_logic_vector(1 downto 0) := "01";
  constant WORM0   : std_logic_vector(1 downto 0) := "10";
  constant WORM1   : std_logic_vector(1 downto 0) := "11";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal state     : std_logic_vector(1 downto 0);
  signal nxt_state : std_logic_vector(1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '0') then
        state <= NOWORM0;
      else
        state <= nxt_state;
      end if;
    end if;
  end process;

  processing_1 : process (state)
    variable out_mux_last_sgn  : std_logic;
    variable out_mux_valid_sgn : std_logic;
  begin
    nxt_state         <= state;
    out_mux_valid_sgn := '0';
    out_mux_data      <= (others => 'X');
    out_mux_last_sgn  := 'X';
    in0_ready         <= '0';
    in1_ready         <= '0';

    case (state) is
      when NOWORM0 =>
        if (in0_valid = '1') then
          out_mux_data      <= in0_data;
          out_mux_last_sgn  := in0_last;
          out_mux_valid_sgn := '1';
          in0_ready         <= out_mux_ready;
          if (in0_last = '0') then
            nxt_state <= WORM0;
          end if;
        elsif (in1_valid = '1') then
          out_mux_data      <= in1_data;
          out_mux_last_sgn  := in1_last;
          out_mux_valid_sgn := '1';
          in1_ready         <= out_mux_ready;

          if (in1_last = '0') then
            nxt_state <= WORM1;
          end if;
        end if;
      when NOWORM1 =>
        if (in1_valid = '1') then
          out_mux_data      <= in1_data;
          out_mux_last_sgn  := in1_last;
          out_mux_valid_sgn := '1';
          in1_ready         <= out_mux_ready;

          if (in1_last = '0') then
            nxt_state <= WORM1;
          end if;
        elsif (in0_valid = '0') then
          out_mux_data      <= in0_data;
          out_mux_last_sgn  := in0_last;
          out_mux_valid_sgn := '1';
          in0_ready         <= out_mux_ready;

          if (in0_last = '0') then
            nxt_state <= WORM0;
          end if;
        end if;
      when WORM0 =>
        out_mux_data      <= in1_data;
        out_mux_last_sgn  := in1_last;
        out_mux_valid_sgn := in1_valid;
        in0_ready         <= out_mux_ready;
        if (out_mux_last_sgn = '1' and out_mux_valid_sgn = '1' and out_mux_ready = '1') then
          nxt_state <= NOWORM1;
        end if;
      when WORM1 =>
        out_mux_data      <= in1_data;
        out_mux_last_sgn  := in1_last;
        out_mux_valid_sgn := in1_valid;
        in0_ready         <= out_mux_ready;
        if (out_mux_last_sgn = '1' and out_mux_valid_sgn = '1' and out_mux_ready = '1') then
          nxt_state <= NOWORM0;
        end if;
      when others =>
        null;
    end case;

    out_mux_last  <= out_mux_last_sgn;
    out_mux_valid <= out_mux_valid_sgn;
  end process;
end RTL;
