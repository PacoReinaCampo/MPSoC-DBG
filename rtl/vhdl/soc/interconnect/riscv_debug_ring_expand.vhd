-- Converted from rtl/verilog/interconnect/riscv_debug_ring_expand.sv
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

entity riscv_debug_ring_expand is
  generic (
    XLEN     : integer := 64;
    CHANNELS : integer := 2;
    NODES    : integer := 2
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
end riscv_debug_ring_expand;

architecture RTL of riscv_debug_ring_expand is
  component riscv_ring_router
    generic (
      XLEN : integer := 64
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
      local_out_ready : in  std_logic
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal chain_data  : std_logic_3array(CHANNELS-1 downto 0)(NODES-1 downto 0)(XLEN-1 downto 0);
  signal chain_last  : std_logic_matrix(CHANNELS-1 downto 0)(NODES-1 downto 0);
  signal chain_valid : std_logic_matrix(CHANNELS-1 downto 0)(NODES-1 downto 0);
  signal chain_ready : std_logic_matrix(CHANNELS-1 downto 0)(NODES-1 downto 0);

--////////////////////////////////////////////////////////////////
--
-- Module Body
--
begin
  generating_0 : for i in 0 to NODES - 1 generate
    ring_router : riscv_ring_router
      generic map (
        XLEN => XLEN
      )
      port map (
        clk => clk,
        rst => rst,

        id => id_map(i),

        ring_in0_data  => chain_data(0)(i),
        ring_in0_last  => chain_last(0)(i),
        ring_in0_valid => chain_valid(0)(i),
        ring_in0_ready => chain_ready(0)(i),

        ring_in1_data  => chain_data(1)(i),
        ring_in1_last  => chain_last(1)(i),
        ring_in1_valid => chain_valid(1)(i),
        ring_in1_ready => chain_ready(1)(i),

        ring_out0_data  => chain_data(0)(i+1),
        ring_out0_last  => chain_last(0)(i+1),
        ring_out0_valid => chain_valid(0)(i+1),
        ring_out0_ready => chain_ready(0)(i+1),

        ring_out1_data  => chain_data(1)(i+1),
        ring_out1_last  => chain_last(1)(i+1),
        ring_out1_valid => chain_valid(1)(i+1),
        ring_out1_ready => chain_ready(1)(i+1),

        local_in_data  => dii_in_data(i),
        local_in_last  => dii_in_last(i),
        local_in_valid => dii_in_valid(i),
        local_in_ready => dii_in_ready(i),

        local_out_data  => dii_out_data(i),
        local_out_last  => dii_out_last(i),
        local_out_valid => dii_out_valid(i),
        local_out_ready => dii_out_ready(i)
      );
  end generate;

  -- the expanded ports
  generating_1 : for i in 0 to CHANNELS - 1 generate
    chain_data(i)(0)  <= ext_in_data(i);
    chain_last(i)(0)  <= ext_in_last(i);
    chain_valid(i)(0) <= ext_in_valid(i);

    ext_in_ready(i) <= chain_ready(i)(0);

    ext_out_data(i)  <= chain_data(i)(NODES);
    ext_out_last(i)  <= chain_last(i)(NODES);
    ext_out_valid(i) <= chain_valid(i)(NODES);

    chain_ready(i)(NODES) <= ext_out_ready(i);
  end generate;
end RTL;
