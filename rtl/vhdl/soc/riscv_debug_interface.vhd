-- Converted from rtl/verilog/riscv_debug_interface.sv
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

entity riscv_debug_interface is
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
end riscv_debug_interface;

architecture RTL of riscv_debug_interface is
  component riscv_ring_router_gateway
    generic (
      XLEN        : integer := 64;
      BUFFER_SIZE : integer := 4
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      id : in std_logic_vector(XLEN-1 downto 0);

      ring_in0_data  : in  std_logic_vector(XLEN-1 downto 0);
      ring_in0_last  : in  std_logic;
      ring_in0_valid : in  std_logic;
      ring_in0_ready : out std_logic;

      ring_in1_data  : in  std_logic_vector(XLEN-1 downto 0);
      ring_in1_last  : in  std_logic;
      ring_in1_valid : in  std_logic;
      ring_in1_ready : out std_logic;

      ring_out0_data  : out std_logic_vector(XLEN-1 downto 0);
      ring_out0_last  : out std_logic;
      ring_out0_valid : out std_logic;
      ring_out0_ready : in  std_logic;

      ring_out1_data  : out std_logic_vector(XLEN-1 downto 0);
      ring_out1_last  : out std_logic;
      ring_out1_valid : out std_logic;
      ring_out1_ready : in  std_logic;

      local_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      local_in_last  : in  std_logic;
      local_in_valid : in  std_logic;
      local_in_ready : out std_logic;

      local_out_data  : out std_logic_vector(XLEN-1 downto 0);
      local_out_last  : out std_logic;
      local_out_valid : out std_logic;
      local_out_ready : in  std_logic;

      ext_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      ext_in_last  : in  std_logic;
      ext_in_valid : in  std_logic;
      ext_in_ready : out std_logic;

      ext_out_data  : out std_logic_vector(XLEN-1 downto 0);
      ext_out_last  : out std_logic;
      ext_out_valid : out std_logic;
      ext_out_ready : in  std_logic
    );
  end component;

  component riscv_osd_him
    generic (
      XLEN        : integer := 64;
      BUFFER_SIZE : integer := 4
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      --GLIP host connection
      glip_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      glip_in_valid : in  std_logic;
      glip_in_ready : out std_logic;

      glip_out_data  : out std_logic_vector(XLEN-1 downto 0);
      glip_out_valid : out std_logic;
      glip_out_ready : in  std_logic;

      dii_out_data  : out std_logic_vector(XLEN-1 downto 0);
      dii_out_last  : out std_logic;
      dii_out_valid : out std_logic;
      dii_out_ready : in  std_logic;

      dii_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      dii_in_last  : in  std_logic;
      dii_in_valid : in  std_logic;
      dii_in_ready : out std_logic
    );
  end component;

  component riscv_osd_scm
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      MAX_REG_SIZE : integer := 64
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      id : in std_logic_vector(XLEN-1 downto 0);

      debug_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      debug_in_last  : in  std_logic;
      debug_in_valid : in  std_logic;
      debug_in_ready : out std_logic;

      debug_out_data  : out std_logic_vector(XLEN-1 downto 0);
      debug_out_last  : out std_logic;
      debug_out_valid : out std_logic;
      debug_out_ready : in  std_logic;

      sys_rst : out std_logic;
      cpu_rst : out std_logic
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal ring_tie_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_tie_last  : std_logic;
  signal ring_tie_valid : std_logic;
  signal ring_tie_ready : std_logic;

  signal dii_in_data  : std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
  signal dii_in_last  : std_logic_vector(CHANNELS-1 downto 0);
  signal dii_in_valid : std_logic_vector(CHANNELS-1 downto 0);
  signal dii_in_ready : std_logic_vector(CHANNELS-1 downto 0);

  signal dii_out_data  : std_logic_matrix(CHANNELS-1 downto 0)(XLEN-1 downto 0);
  signal dii_out_last  : std_logic_vector(CHANNELS-1 downto 0);
  signal dii_out_valid : std_logic_vector(CHANNELS-1 downto 0);
  signal dii_out_ready : std_logic_vector(CHANNELS-1 downto 0);

  signal him_debug_in_data  : std_logic_vector(XLEN-1 downto 0);
  signal him_debug_in_last  : std_logic;
  signal him_debug_in_valid : std_logic;
  signal him_debug_in_ready : std_logic;

  signal him_debug_out_data  : std_logic_vector(XLEN-1 downto 0);
  signal him_debug_out_last  : std_logic;
  signal him_debug_out_valid : std_logic;
  signal him_debug_out_ready : std_logic;

  signal scm_debug_in_data  : std_logic_vector(XLEN-1 downto 0);
  signal scm_debug_in_last  : std_logic;
  signal scm_debug_in_valid : std_logic;
  signal scm_debug_in_ready : std_logic;

  signal scm_debug_out_data  : std_logic_vector(XLEN-1 downto 0);
  signal scm_debug_out_last  : std_logic;
  signal scm_debug_out_valid : std_logic;
  signal scm_debug_out_ready : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  ring_tie_valid <= '0';

  ring_router_gateway : riscv_ring_router_gateway
    generic map (
      XLEN        => XLEN,
      BUFFER_SIZE => BUFFER_SIZE
    )
    port map (
      clk => clk,
      rst => rst,

      -- the gateway is always at local address 0
      id => X"0000000000000000",

      ring_in0_data  => ring_in_data(0),
      ring_in0_last  => ring_in_last(0),
      ring_in0_valid => ring_in_valid(0),
      ring_in0_ready => ring_in_ready(0),

      ring_in1_data  => ring_in_data(1),
      ring_in1_last  => ring_in_last(1),
      ring_in1_valid => ring_in_valid(1),
      ring_in1_ready => ring_in_ready(1),

      ring_out0_data  => ring_out_data(0),
      ring_out0_last  => ring_out_last(0),
      ring_out0_valid => ring_out_valid(0),
      ring_out0_ready => ring_out_ready(0),

      ring_out1_data  => ring_out_data(1),
      ring_out1_last  => ring_out_last(1),
      ring_out1_valid => ring_out_valid(1),
      ring_out1_ready => ring_out_ready(1),

      -- local traffic for address 0: SCM
      local_in_data  => scm_debug_out_data,
      local_in_last  => scm_debug_out_last,
      local_in_valid => scm_debug_out_valid,
      local_in_ready => scm_debug_out_ready,

      local_out_data  => scm_debug_in_data,
      local_out_last  => scm_debug_in_last,
      local_out_valid => scm_debug_in_valid,
      local_out_ready => scm_debug_in_ready,

      -- traffic not belonging to LOCAL_SUBNET (sent out to the host)
      ext_in_data  => him_debug_out_data,
      ext_in_last  => him_debug_out_last,
      ext_in_valid => him_debug_out_valid,
      ext_in_ready => him_debug_out_ready,

      ext_out_data  => him_debug_in_data,
      ext_out_last  => him_debug_in_last,
      ext_out_valid => him_debug_in_valid,
      ext_out_ready => him_debug_in_ready
    );

  -- Host Interface: all traffic to foreign subnets goes through this interface
  osd_him : riscv_osd_him
    generic map (
      XLEN        => XLEN,
      BUFFER_SIZE => BUFFER_SIZE
    )
    port map (
      clk => clk,
      rst => rst,

      glip_in_data  => glip_in_data,
      glip_in_valid => glip_in_valid,
      glip_in_ready => glip_in_ready,

      glip_out_data  => glip_out_data,
      glip_out_valid => glip_out_valid,
      glip_out_ready => glip_out_ready,

      dii_out_data  => him_debug_out_data,
      dii_out_last  => him_debug_out_last,
      dii_out_valid => him_debug_out_valid,
      dii_out_ready => him_debug_out_ready,

      dii_in_data  => him_debug_in_data,
      dii_in_last  => him_debug_in_last,
      dii_in_valid => him_debug_in_valid,
      dii_in_ready => him_debug_in_ready
    );

  -- Subnet Control Module
  -- Manages this subnet, i.e. the on-chip OSD part
  osd_scm : riscv_osd_scm
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      MAX_REG_SIZE => MAX_REG_SIZE
    )
    port map (
      clk => clk,
      rst => rst,

      id => (others => '0'),

      debug_in_data  => scm_debug_in_data,
      debug_in_last  => scm_debug_in_last,
      debug_in_valid => scm_debug_in_valid,
      debug_in_ready => scm_debug_in_ready,

      debug_out_data  => scm_debug_out_data,
      debug_out_last  => scm_debug_out_last,
      debug_out_valid => scm_debug_out_valid,
      debug_out_ready => scm_debug_out_ready,

      sys_rst => sys_rst,
      cpu_rst => cpu_rst
    );
end RTL;
