-- Converted from rtl/verilog/interconnect/riscv_debug_ring.sv
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

entity riscv_debug_ring is
  generic (
    XLEN     : integer := 64;
    CHANNELS : integer := 2;
    NODES    : integer := 2
  );
  port (
    clk    : in std_logic;
    rst    : in std_logic;
    id_map : in std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);

    dii_in_data  : in  std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
    dii_in_last  : in  std_logic_vector(NODES-1 downto 0);
    dii_in_valid : in  std_logic_vector(NODES-1 downto 0);
    dii_in_ready : out std_logic_vector(NODES-1 downto 0);

    dii_out_data  : out std_logic_matrix(NODES-1 downto 0)(XLEN-1 downto 0);
    dii_out_last  : out std_logic_vector(NODES-1 downto 0);
    dii_out_valid : out std_logic_vector(NODES-1 downto 0);
    dii_out_ready : in  std_logic_vector(NODES-1 downto 0)
  );
end riscv_debug_ring;

architecture RTL of riscv_debug_ring is
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
  signal ext_port_data  : std_logic_3array(NODES-1 downto 0)(CHANNELS-1 downto 0)(XLEN-1 downto 0);
  signal ext_port_last  : std_logic_matrix(NODES-1 downto 0)(CHANNELS-1 downto 0);
  signal ext_port_valid : std_logic_matrix(NODES-1 downto 0)(CHANNELS-1 downto 0);
  signal ext_port_ready : std_logic_matrix(NODES-1 downto 0)(CHANNELS-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  debug_ring_expand : riscv_debug_ring_expand
    generic map (
      XLEN     => XLEN,
      CHANNELS => CHANNELS,
      NODES    => NODES
    )
    port map (
      clk => clk,
      rst => rst,

      id_map => id_map,

      dii_in_data  => dii_in_data,
      dii_in_last  => dii_in_last,
      dii_in_valid => dii_in_valid,
      dii_in_ready => dii_in_ready,

      dii_out_data  => dii_out_data,
      dii_out_last  => dii_out_last,
      dii_out_valid => dii_out_valid,
      dii_out_ready => dii_out_ready,

      ext_in_data  => ext_port_data(0),
      ext_in_last  => ext_port_last(0),
      ext_in_valid => ext_port_valid(0),
      ext_in_ready => ext_port_ready(0),

      ext_out_data  => ext_port_data(1),
      ext_out_last  => ext_port_last(1),
      ext_out_valid => ext_port_valid(1),
      ext_out_ready => ext_port_ready(1)
    );

  -- empty input for chain 0
  ext_port_valid(0)(0) <= '0';

  -- connect the ends of chain 0 & 1
  ext_port_data(0)(1)  <= ext_port_data(1)(0);
  ext_port_last(0)(1)  <= ext_port_last(1)(0);
  ext_port_valid(0)(1) <= ext_port_valid(1)(0);
  ext_port_ready(1)(0) <= ext_port_ready(0)(1);

  -- dump chain 1
  ext_port_ready(1)(1) <= '1';
end RTL;
