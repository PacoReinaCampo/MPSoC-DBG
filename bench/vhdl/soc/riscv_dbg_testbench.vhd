-- Converted from bench/verilog/regression/riscv_dbg_testbench.sv
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
use work.riscv_dbg_pkg.all;

entity riscv_dbg_testbench is
end riscv_dbg_testbench;

architecture RTL of riscv_dbg_testbench is
  component riscv_debug_interface
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      MAX_REG_SIZE : integer := 64;

      BUFFER_SIZE : integer := 4;

      CHANNELS : integer := 2
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      -- GLIP host connection
      glip_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      glip_in_valid : in  std_logic;
      glip_in_ready : out std_logic;

      glip_out_data  : out std_logic_vector(XLEN-1 downto 0);
      glip_out_valid : out std_logic;
      glip_out_ready : in  std_logic;

      -- ring connection
      ring_out_data  : out std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
      ring_out_last  : out std_logic_vector(CHANNELS-1 downto 0);
      ring_out_valid : out std_logic_vector(CHANNELS-1 downto 0);
      ring_out_ready : in  std_logic_vector(CHANNELS-1 downto 0);

      ring_in_data  : in  std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
      ring_in_last  : in  std_logic_vector(CHANNELS-1 downto 0);
      ring_in_valid : in  std_logic_vector(CHANNELS-1 downto 0);
      ring_in_ready : out std_logic_vector(CHANNELS-1 downto 0);

      -- system reset request
      sys_rst : out std_logic;

      -- CPU reset request
      cpu_rst : out std_logic
    );
  end component;

  component riscv_debug_ring
    generic (
      XLEN     : integer := 64;
      CHANNELS : integer := 2;
      NODES    : integer := 1
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      id_map   : in std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);

      dii_in_data  : in  std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
      dii_in_last  : in  std_logic_vector(NODES-1 downto 0);
      dii_in_valid : in  std_logic_vector(NODES-1 downto 0);
      dii_in_ready : out std_logic_vector(NODES-1 downto 0);

      dii_out_data  : out std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
      dii_out_last  : out std_logic_vector(NODES-1 downto 0);
      dii_out_valid : out std_logic_vector(NODES-1 downto 0);
      dii_out_ready : in  std_logic_vector(NODES-1 downto 0)
    );
  end component;

  component riscv_debug_ring_expand
    generic (
      XLEN     : integer := 64;
      CHANNELS : integer := 2;
      NODES    : integer := 1
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      id_map : in std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);

      dii_in_data  : in  std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
      dii_in_last  : in  std_logic_vector(NODES-1 downto 0);
      dii_in_valid : in  std_logic_vector(NODES-1 downto 0);
      dii_in_ready : out std_logic_vector(NODES-1 downto 0);

      dii_out_data  : out std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
      dii_out_last  : out std_logic_vector(NODES-1 downto 0);
      dii_out_valid : out std_logic_vector(NODES-1 downto 0);
      dii_out_ready : in  std_logic_vector(NODES-1 downto 0);

      ext_in_data  : in  std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
      ext_in_last  : in  std_logic_vector(CHANNELS-1 downto 0);
      ext_in_valid : in  std_logic_vector(CHANNELS-1 downto 0);
      ext_in_ready : out std_logic_vector(CHANNELS-1 downto 0);  -- extension input ports

      ext_out_data  : out std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
      ext_out_last  : out std_logic_vector(CHANNELS-1 downto 0);
      ext_out_valid : out std_logic_vector(CHANNELS-1 downto 0);
      ext_out_ready : in  std_logic_vector(CHANNELS-1 downto 0)  -- extension output ports
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  signal HCLK    : std_logic;
  signal HRESETn : std_logic;

  signal rst_sys : std_logic;
  signal rst_cpu : std_logic;

  --GLIP host connection
  signal glip_in_data  : std_logic_vector(XLEN-1 downto 0);
  signal glip_in_valid : std_logic;
  signal glip_in_ready : std_logic;

  signal glip_out_data  : std_logic_vector(XLEN-1 downto 0);
  signal glip_out_valid : std_logic;
  signal glip_out_ready : std_logic;

  signal debug_ring_in_data  : std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
  signal debug_ring_in_last  : std_logic_vector(CHANNELS-1 downto 0);
  signal debug_ring_in_valid : std_logic_vector(CHANNELS-1 downto 0);
  signal debug_ring_in_ready : std_logic_vector(CHANNELS-1 downto 0);

  signal debug_ring_out_data  : std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
  signal debug_ring_out_last  : std_logic_vector(CHANNELS-1 downto 0);
  signal debug_ring_out_valid : std_logic_vector(CHANNELS-1 downto 0);
  signal debug_ring_out_ready : std_logic_vector(CHANNELS-1 downto 0);

  signal id_map : std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);

  signal dii_in_data  : std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
  signal dii_in_last  : std_logic_vector(NODES-1 downto 0);
  signal dii_in_valid : std_logic_vector(NODES-1 downto 0);
  signal dii_in_ready : std_logic_vector(NODES-1 downto 0);

  signal dii_in_expand_data  : std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
  signal dii_in_expand_last  : std_logic_vector(NODES-1 downto 0);
  signal dii_in_expand_valid : std_logic_vector(NODES-1 downto 0);
  signal dii_in_expand_ready : std_logic_vector(NODES-1 downto 0);

  signal dii_out_data  : std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
  signal dii_out_last  : std_logic_vector(NODES-1 downto 0);
  signal dii_out_valid : std_logic_vector(NODES-1 downto 0);
  signal dii_out_ready : std_logic_vector(NODES-1 downto 0);

  signal dii_out_expand_data  : std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
  signal dii_out_expand_last  : std_logic_vector(NODES-1 downto 0);
  signal dii_out_expand_valid : std_logic_vector(NODES-1 downto 0);
  signal dii_out_expand_ready : std_logic_vector(NODES-1 downto 0);

  signal ext_in_data  : std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
  signal ext_in_last  : std_logic_vector(CHANNELS-1 downto 0);
  signal ext_in_valid : std_logic_vector(CHANNELS-1 downto 0);
  signal ext_in_ready : std_logic_vector(CHANNELS-1 downto 0);  -- extension input ports

  signal ext_out_data  : std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
  signal ext_out_last  : std_logic_vector(CHANNELS-1 downto 0);
  signal ext_out_valid : std_logic_vector(CHANNELS-1 downto 0);
  signal ext_out_ready : std_logic_vector(CHANNELS-1 downto 0);  -- extension output ports

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --DUT
  debug_interface : riscv_debug_interface
    generic map (
      XLEN     => XLEN,
      PLEN     => PLEN,

      MAX_REG_SIZE => MAX_REG_SIZE,

      BUFFER_SIZE => BUFFER_SIZE,

      CHANNELS    => CHANNELS
    )
    port map (
      clk => HCLK,
      rst => HRESETn,

      sys_rst => rst_sys,
      cpu_rst => rst_cpu,

      glip_in_data  => glip_in_data,
      glip_in_valid => glip_in_valid,
      glip_in_ready => glip_in_ready,

      glip_out_data  => glip_out_data,
      glip_out_valid => glip_out_valid,
      glip_out_ready => glip_out_ready,

      ring_out_data  => debug_ring_in_data,
      ring_out_last  => debug_ring_in_last,
      ring_out_valid => debug_ring_in_valid,
      ring_out_ready => debug_ring_in_ready,

      ring_in_data  => debug_ring_out_data,
      ring_in_last  => debug_ring_out_last,
      ring_in_valid => debug_ring_out_valid,
      ring_in_ready => debug_ring_out_ready
    );

  debug_ring : riscv_debug_ring
    generic map (
      XLEN     => XLEN,
      CHANNELS => CHANNELS,
      NODES    => NODES
    )
    port map (
      clk => HCLK,
      rst => HRESETn,

      id_map => id_map,

      dii_in_data  => dii_in_data,
      dii_in_last  => dii_in_last,
      dii_in_valid => dii_in_valid,
      dii_in_ready => dii_in_ready,

      dii_out_data  => dii_out_data,
      dii_out_last  => dii_out_last,
      dii_out_valid => dii_out_valid,
      dii_out_ready => dii_out_ready
    );

  debug_ring_expand : riscv_debug_ring_expand
    generic map (
      XLEN     => XLEN,
      CHANNELS => CHANNELS,
      NODES    => NODES
    )
    port map (
      clk => HCLK,
      rst => HRESETn,

      id_map => id_map,

      dii_in_data  => dii_in_expand_data,
      dii_in_last  => dii_in_expand_last,
      dii_in_valid => dii_in_expand_valid,
      dii_in_ready => dii_in_expand_ready,

      dii_out_data  => dii_out_expand_data,
      dii_out_last  => dii_out_expand_last,
      dii_out_valid => dii_out_expand_valid,
      dii_out_ready => dii_out_expand_ready,

      ext_in_data  => ext_in_data,
      ext_in_last  => ext_in_last,
      ext_in_valid => ext_in_valid,
      ext_in_ready => ext_in_ready,

      ext_out_data  => ext_out_data,
      ext_out_last  => ext_out_last,
      ext_out_valid => ext_out_valid,
      ext_out_ready => ext_out_ready
    );
end RTL;
