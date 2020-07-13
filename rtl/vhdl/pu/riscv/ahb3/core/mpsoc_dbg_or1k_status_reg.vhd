-- Converted from rtl/verilog/core/mpsoc_dbg_or1k_status_reg.sv
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

entity mpsoc_dbg_or1k_status_reg is
  generic (
    X : integer := 2;
    Y : integer := 2;
    Z : integer := 2;

    CORES_PER_TILE : integer := 1
    );
  port (
    tlr_i      : in  std_logic;
    tck_i      : in  std_logic;
    we_i       : in  std_logic;
    ctrl_reg_o : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

    cpu_rstn_i  : in  std_logic;
    cpu_clk_i   : in  std_logic;
    data_i      : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    bp_i        : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    cpu_stall_o : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)
    );
end mpsoc_dbg_or1k_status_reg;

architecture RTL of mpsoc_dbg_or1k_status_reg is
  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal stall_bp      : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal stall_bp_csff : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal stall_bp_tck  : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

  signal stall_reg      : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal stall_reg_csff : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal stall_reg_cpu  : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Breakpoint is latched and synchronized. Stall is set and latched.
  -- This is done in the CPU clock domain, because the JTAG clock (TCK) is
  -- irregular.  By only allowing bp_i to set (but not reset) the stall_bp
  -- signal, we insure that the CPU will remain in the stalled state until
  -- the debug host can read the state.
  generating_0 : for i in 0 to X - 1 generate
    generating_1 : for j in 0 to Y - 1 generate
      generating_2 : for k in 0 to Z - 1 generate
        generating_3 : for t in 0 to CORES_PER_TILE - 1 generate
          processing_0 : process (cpu_clk_i, cpu_rstn_i)
          begin
            if (cpu_rstn_i = '0') then
              stall_bp(i, j, k)(t) <= '0';
            elsif (rising_edge(cpu_clk_i)) then
              if (bp_i(i, j, k)(t) = '0') then
                stall_bp(i, j, k)(t) <= '1';
              elsif (stall_reg_cpu(i, j, k)(t) = '0') then
                stall_bp(i, j, k)(t) <= '0';
              end if;
            end if;
          end process;
        end generate;
      end generate;
    end generate;
  end generate;

  -- Synchronizing
  processing_1 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      stall_bp_csff <= (others => (others => (others => (others => '0'))));
      stall_bp_tck  <= (others => (others => (others => (others => '0'))));
    elsif (rising_edge(tck_i)) then
      stall_bp_csff <= stall_bp;
      stall_bp_tck  <= stall_bp_csff;
    end if;
  end process;

  processing_2 : process (cpu_clk_i, cpu_rstn_i)
  begin
    if (cpu_rstn_i = '0') then
      stall_reg_csff <= (others => (others => (others => (others => '0'))));
      stall_reg_cpu  <= (others => (others => (others => (others => '0'))));
    elsif (rising_edge(cpu_clk_i)) then
      stall_reg_csff <= stall_reg;
      stall_reg_cpu  <= stall_reg_csff;
    end if;
  end process;

  -- bp_i forces a stall immediately on a breakpoint
  -- stall_bp holds the stall until the debug host acts
  -- stall_reg_cpu allows the debug host to control a stall.
  generating_4 : for i in 0 to X - 1 generate
    generating_5 : for j in 0 to Y - 1 generate
      generating_6 : for k in 0 to Z - 1 generate
        cpu_stall_o(i, j, k) <= bp_i(i, j, k) or stall_bp(i, j, k) or stall_reg_cpu(i, j, k);
      end generate;
    end generate;
  end generate;

  -- Writing data to the control registers (stall)
  -- This can be set either by the debug host, or by
  -- a CPU breakpoint.  It can only be cleared by the host.
  generating_6 : for i in 0 to X - 1 generate
    generating_7 : for j in 0 to Y - 1 generate
      generating_8 : for k in 0 to Z - 1 generate
        generating_9 : for t in 0 to CORES_PER_TILE - 1 generate
          processing_3 : process (tck_i, tlr_i)
          begin
            if (tlr_i = '1') then
              stall_reg(i, j, k)(t) <= '0';
            elsif (rising_edge(tck_i)) then
              if (stall_bp_tck(i, j, k)(t) = '0') then
                stall_reg(i, j, k)(t) <= '1';
              elsif (we_i = '1') then
                stall_reg(i, j, k)(t) <= data_i(i, j, k)(t);
              end if;
            end if;
          end process;
        end generate;
      end generate;
    end generate;
  end generate;

  -- Value for read back
  ctrl_reg_o <= stall_reg;
end RTL;
