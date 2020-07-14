-- Converted from rtl/verilog/interconnect/riscv_ring_router_gateway_mux.sv
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

entity riscv_ring_router_gateway_mux is
  generic (
    XLEN : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    in_ring_data  : in  std_logic_vector(XLEN-1 downto 0);
    in_ring_last  : in  std_logic;
    in_ring_valid : in  std_logic;
    in_ring_ready : out std_logic;

    in_local_data  : in  std_logic_vector(XLEN-1 downto 0);
    in_local_last  : in  std_logic;
    in_local_valid : in  std_logic;
    in_local_ready : out std_logic;

    in_ext_data  : in  std_logic_vector(XLEN-1 downto 0);
    in_ext_last  : in  std_logic;
    in_ext_valid : in  std_logic;
    in_ext_ready : out std_logic;

    out_mux_data  : out std_logic_vector(XLEN-1 downto 0);
    out_mux_last  : out std_logic;
    out_mux_valid : out std_logic;
    out_mux_ready : in  std_logic
    );
end riscv_ring_router_gateway_mux;

architecture RTL of riscv_ring_router_gateway_mux is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant NOWORM     : std_logic_vector(1 downto 0) := "00";
  constant WORM_LOCAL : std_logic_vector(1 downto 0) := "01";
  constant WORM_EXT   : std_logic_vector(1 downto 0) := "10";
  constant WORM_RING  : std_logic_vector(1 downto 0) := "11";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal state     : std_logic_vector(1 downto 0);
  signal nxt_state : std_logic_vector(1 downto 0);

  signal mux_last  : std_logic;
  signal mux_valid : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        state <= NOWORM;
      else
        state <= nxt_state;
      end if;
    end if;
  end process;

  processing_1 : process (state)
    variable mux_last  : std_logic;
    variable mux_valid : std_logic;
  begin
    nxt_state      <= state;
    mux_valid      := '0';
    out_mux_data   <= (others => 'X');
    mux_last       := 'X';
    in_ring_ready  <= '0';
    in_local_ready <= '0';
    in_ext_ready   <= '0';

    case (state) is
      when NOWORM =>
        if (in_ring_valid = '1') then
          out_mux_data  <= in_ring_data;
          mux_last      := in_ring_last;
          mux_valid     := '1';
          in_ring_ready <= out_mux_ready;
          if (in_ring_last = '0') then
            nxt_state <= WORM_RING;
          end if;
        elsif (in_local_valid = '1') then
          out_mux_data   <= in_local_data;
          mux_last       := in_local_last;
          mux_valid      := '1';
          in_local_ready <= out_mux_ready;
          if (in_local_last = '0') then
            nxt_state <= WORM_LOCAL;
          end if;
        elsif (in_ext_valid = '1') then
          out_mux_data <= in_ext_data;
          mux_last     := in_ext_last;
          mux_valid    := '1';
          in_ext_ready <= out_mux_ready;
          if (in_ext_last = '0') then
            nxt_state <= WORM_EXT;
          end if;
        end if;
      -- case: NOWORM
      when WORM_RING =>
        in_ring_ready <= out_mux_ready;
        mux_valid     := in_ring_valid;
        mux_last      := in_ring_last;
        out_mux_data  <= in_ring_data;
        if (mux_last = '1' and mux_valid = '1' and out_mux_ready = '1') then
          nxt_state <= NOWORM;
        end if;
      when WORM_LOCAL =>
        in_local_ready <= out_mux_ready;
        mux_valid      := in_local_valid;
        mux_last       := in_local_last;
        out_mux_data   <= in_local_data;

        if (mux_last = '1' and mux_valid = '1' and out_mux_ready = '1') then
          nxt_state <= NOWORM;
        end if;
      when WORM_EXT =>
        in_ext_ready <= out_mux_ready;
        mux_valid    := in_ext_valid;
        mux_last     := in_ext_last;
        out_mux_data <= in_ext_data;
        if (mux_last = '1' and mux_valid = '1' and out_mux_ready = '1') then
          nxt_state <= NOWORM;
        end if;
      when others =>
        null;
    end case;

    out_mux_last  <= mux_last;
    out_mux_valid <= mux_valid;
  end process;
end RTL;
