-- Converted from rtl/verilog/blocks/regaccess/riscv_osd_regaccess_layer.sv
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

entity riscv_osd_regaccess_layer is
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

    module_in_data  : in  std_logic_vector(XLEN-1 downto 0);
    module_in_last  : in  std_logic;
    module_in_valid : in  std_logic;
    module_in_ready : out std_logic;

    module_out_data  : out std_logic_vector(XLEN-1 downto 0);
    module_out_last  : out std_logic;
    module_out_valid : out std_logic;
    module_out_ready : in  std_logic;

    reg_request : out std_logic;
    reg_write   : out std_logic;
    reg_addr    : out std_logic_vector(PLEN-1 downto 0);
    reg_size    : out std_logic_vector(1 downto 0);
    reg_wdata   : out std_logic_vector(MAX_REG_SIZE-1 downto 0);
    reg_ack     : in  std_logic;
    reg_err     : in  std_logic;
    reg_rdata   : in  std_logic_vector(MAX_REG_SIZE-1 downto 0);

    event_dest : out std_logic_vector(XLEN-1 downto 0);  -- DI address of the event destination
    stall      : out std_logic
  );
end riscv_osd_regaccess_layer;

architecture RTL of riscv_osd_regaccess_layer is
  component riscv_osd_regaccess
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

    reg_request : out std_logic;
    reg_write   : out std_logic;
    reg_addr    : out std_logic_vector(PLEN-1 downto 0);
    reg_size    : out std_logic_vector(1 downto 0);
    reg_wdata   : out std_logic_vector(MAX_REG_SIZE-1 downto 0);
    reg_ack     : in  std_logic;
    reg_err     : in  std_logic;
    reg_rdata   : in  std_logic_vector(MAX_REG_SIZE-1 downto 0);

    event_dest : out std_logic_vector(XLEN-1 downto 0);
    stall      : out std_logic
  );
end component;

component riscv_osd_regaccess_demux
  generic (
    XLEN : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    in_data  : in  std_logic_vector(XLEN-1 downto 0);
    in_last  : in  std_logic;
    in_valid : in  std_logic;
    in_ready : out std_logic;

    out_reg_data  : out std_logic_vector(XLEN-1 downto 0);
    out_reg_last  : out std_logic;
    out_reg_valid : out std_logic;
    out_reg_ready : in  std_logic;

    out_bypass_data  : out std_logic_vector(XLEN-1 downto 0);
    out_bypass_last  : out std_logic;
    out_bypass_valid : out std_logic;
    out_bypass_ready : in  std_logic
  );
end component;

component riscv_ring_router_mux
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

    out_mux_data  : out std_logic_vector(XLEN-1 downto 0);
    out_mux_last  : out std_logic;
    out_mux_valid : out std_logic;
    out_mux_ready : in  std_logic
  );
end component;

--////////////////////////////////////////////////////////////////
--
-- Variables
--
signal regaccess_in_data  : std_logic_vector(XLEN-1 downto 0);
signal regaccess_in_last  : std_logic;
signal regaccess_in_valid : std_logic;
signal regaccess_in_ready : std_logic;

signal regaccess_out_data  : std_logic_vector(XLEN-1 downto 0);
signal regaccess_out_last  : std_logic;
signal regaccess_out_valid : std_logic;
signal regaccess_out_ready : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  osd_regaccess : riscv_osd_regaccess
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      MAX_REG_SIZE => MAX_REG_SIZE
    )
    port map (
      clk => clk,
      rst => rst,

      id => id,

      debug_in_data  => regaccess_in_data,
      debug_in_last  => regaccess_in_last,
      debug_in_valid => regaccess_in_valid,
      debug_in_ready => regaccess_in_ready,

      debug_out_data  => regaccess_out_data,
      debug_out_last  => regaccess_out_last,
      debug_out_valid => regaccess_out_valid,
      debug_out_ready => regaccess_out_ready,

      reg_request => reg_request,
      reg_write   => reg_write,
      reg_addr    => reg_addr,
      reg_size    => reg_size,
      reg_wdata   => reg_wdata,
      reg_ack     => reg_ack,
      reg_err     => reg_err,
      reg_rdata   => reg_rdata,

      event_dest => event_dest,
      stall      => stall
    );

  -- Ingress path demux
  osd_regaccess_demux : riscv_osd_regaccess_demux
    generic map (
      XLEN => XLEN
    )
    port map (
      clk => clk,
      rst => rst,

      in_data  => debug_in_data,
      in_last  => debug_in_last,
      in_valid => debug_in_valid,
      in_ready => debug_in_ready,

      out_reg_data  => regaccess_in_data,
      out_reg_last  => regaccess_in_last,
      out_reg_valid => regaccess_in_valid,
      out_reg_ready => regaccess_in_ready,

      out_bypass_data  => module_out_data,
      out_bypass_last  => module_out_last,
      out_bypass_valid => module_out_valid,
      out_bypass_ready => module_out_ready
    );

  -- Egress path mux
  ring_router_mux : riscv_ring_router_mux
    generic map (
      XLEN => XLEN
    )
    port map (
      clk => clk,
      rst => rst,

      in_local_data  => module_in_data,
      in_local_last  => module_in_last,
      in_local_valid => module_in_valid,
      in_local_ready => module_in_ready,

      in_ring_data  => regaccess_out_data,
      in_ring_last  => regaccess_out_last,
      in_ring_valid => regaccess_out_valid,
      in_ring_ready => regaccess_out_ready,

      out_mux_data  => debug_out_data,
      out_mux_last  => debug_out_last,
      out_mux_valid => debug_out_valid,
      out_mux_ready => debug_out_ready
    );
end RTL;
