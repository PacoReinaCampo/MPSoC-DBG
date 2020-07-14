-- Converted from rtl/verilog/interconnect/riscv_ring_router_gateway.sv
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
use ieee.math_real.all;

entity riscv_ring_router_gateway is
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
end riscv_ring_router_gateway;

architecture RTL of riscv_ring_router_gateway is
  component riscv_ring_router_gateway_demux
    generic (
      XLEN : integer := 64
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      id : in std_logic_vector(XLEN-1 downto 0);

      in_ring_data  : in  std_logic_vector(XLEN-1 downto 0);
      in_ring_last  : in  std_logic;
      in_ring_valid : in  std_logic;
      in_ring_ready : out std_logic;

      out_local_data  : out std_logic_vector(XLEN-1 downto 0);
      out_local_last  : out std_logic;
      out_local_valid : out std_logic;
      out_local_ready : in  std_logic;

      out_ext_data  : out std_logic_vector(XLEN-1 downto 0);
      out_ext_last  : out std_logic;
      out_ext_valid : out std_logic;
      out_ext_ready : in  std_logic;

      out_ring_data  : out std_logic_vector(XLEN-1 downto 0);
      out_ring_last  : out std_logic;
      out_ring_valid : out std_logic;
      out_ring_ready : in  std_logic
    );
  end component;

  component riscv_ring_router_mux_rr
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
  end component;

  component riscv_ring_router_gateway_mux
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
  end component;

  component riscv_dii_buffer
    generic (
      XLEN        : integer := 64;
      BUFFER_SIZE : integer := 4;
      FULLPACKET  : std_logic := '0'
    );
    port (
      -- length of the buffer
      clk         : in  std_logic;
      rst         : in  std_logic;
      packet_size : out std_logic_vector(integer(log2(real(BUFFER_SIZE))) downto 0);

      flit_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      flit_in_last  : in  std_logic;
      flit_in_valid : in  std_logic;
      flit_in_ready : out std_logic;

      flit_out_data  : out std_logic_vector(XLEN-1 downto 0);
      flit_out_last  : out std_logic;
      flit_out_valid : out std_logic;
      flit_out_ready : in  std_logic
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal ring_fwd0_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_fwd0_last  : std_logic;
  signal ring_fwd0_valid : std_logic;
  signal ring_fwd0_ready : std_logic;

  signal ring_fwd1_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_fwd1_last  : std_logic;
  signal ring_fwd1_valid : std_logic;
  signal ring_fwd1_ready : std_logic;

  signal ring_local0_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_local0_last  : std_logic;
  signal ring_local0_valid : std_logic;
  signal ring_local0_ready : std_logic;

  signal ring_local1_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_local1_last  : std_logic;
  signal ring_local1_valid : std_logic;
  signal ring_local1_ready : std_logic;

  signal ring_ext0_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_ext0_last  : std_logic;
  signal ring_ext0_valid : std_logic;
  signal ring_ext0_ready : std_logic;

  signal ring_ext1_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_ext1_last  : std_logic;
  signal ring_ext1_valid : std_logic;
  signal ring_ext1_ready : std_logic;

  signal ring_muxed_data  : std_logic_vector(XLEN-1 downto 0);
  signal ring_muxed_last  : std_logic;
  signal ring_muxed_valid : std_logic;
  signal ring_muxed_ready : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  u_demux0 : riscv_ring_router_gateway_demux
    generic map (
      XLEN => XLEN
    )
    port map (
      clk => clk,
      rst => rst,

      id => id,

      in_ring_data  => ring_in0_data,
      in_ring_last  => ring_in0_last,
      in_ring_valid => ring_in0_valid,
      in_ring_ready => ring_in0_ready,

      out_local_data  => ring_local0_data,
      out_local_last  => ring_local0_last,
      out_local_valid => ring_local0_valid,
      out_local_ready => ring_local0_ready,

      out_ring_data  => ring_fwd0_data,
      out_ring_last  => ring_fwd0_last,
      out_ring_valid => ring_fwd0_valid,
      out_ring_ready => ring_fwd0_ready,

      out_ext_data  => ring_ext0_data,
      out_ext_last  => ring_ext0_last,
      out_ext_valid => ring_ext0_valid,
      out_ext_ready => ring_ext0_ready
    );

  u_demux1 : riscv_ring_router_gateway_demux
    generic map (
      XLEN => XLEN
    )
    port map (
      clk => clk,
      rst => rst,

      id => id,

      in_ring_data  => ring_in1_data,
      in_ring_last  => ring_in1_last,
      in_ring_valid => ring_in1_valid,
      in_ring_ready => ring_in1_ready,

      out_local_data  => ring_local1_data,
      out_local_last  => ring_local1_last,
      out_local_valid => ring_local1_valid,
      out_local_ready => ring_local1_ready,

      out_ring_data  => ring_fwd1_data,
      out_ring_last  => ring_fwd1_last,
      out_ring_valid => ring_fwd1_valid,
      out_ring_ready => ring_fwd1_ready,

      out_ext_data  => ring_ext1_data,
      out_ext_last  => ring_ext1_last,
      out_ext_valid => ring_ext1_valid,
      out_ext_ready => ring_ext1_ready
    );

  u_mux_local : riscv_ring_router_mux_rr
    generic map (
      XLEN => XLEN
    )
    port map (
      clk => clk,
      rst => rst,

      in0_data  => ring_local0_data,
      in0_last  => ring_local0_last,
      in0_valid => ring_local0_valid,
      in0_ready => ring_local0_ready,

      in1_data  => ring_local1_data,
      in1_last  => ring_local1_last,
      in1_valid => ring_local1_valid,
      in1_ready => ring_local1_ready,

      out_mux_data  => local_out_data,
      out_mux_last  => local_out_last,
      out_mux_valid => local_out_valid,
      out_mux_ready => local_out_ready
    );

  u_mux_ext : riscv_ring_router_mux_rr
    generic map (
      XLEN => XLEN
    )
    port map (
      clk => clk,
      rst => rst,

      in0_data      => ring_ext0_data,
      in0_last      => ring_ext0_last,
      in0_valid     => ring_ext0_valid,
      in0_ready     => ring_ext0_ready,
      in1_data      => ring_ext1_data,
      in1_last      => ring_ext1_last,
      in1_valid     => ring_ext1_valid,
      in1_ready     => ring_ext1_ready,
      out_mux_data  => ext_out_data,
      out_mux_last  => ext_out_last,
      out_mux_valid => ext_out_valid,
      out_mux_ready => ext_out_ready
    );

  u_mux_ring0 : riscv_ring_router_gateway_mux
    generic map (
      XLEN => XLEN
    )
    port map (
      clk => clk,
      rst => rst,

      in_ring_data  => ring_fwd0_data,
      in_ring_last  => ring_fwd0_last,
      in_ring_valid => ring_fwd0_valid,
      in_ring_ready => ring_fwd0_ready,

      in_local_data  => local_in_data,
      in_local_last  => local_in_last,
      in_local_valid => local_in_valid,
      in_local_ready => local_in_ready,

      in_ext_data  => ext_in_data,
      in_ext_last  => ext_in_last,
      in_ext_valid => ext_in_valid,
      in_ext_ready => ext_in_ready,

      out_mux_data  => ring_muxed_data,
      out_mux_last  => ring_muxed_last,
      out_mux_valid => ring_muxed_valid,
      out_mux_ready => ring_muxed_ready
    );

  u_buffer0 : riscv_dii_buffer
    generic map (
      XLEN        => XLEN,
      BUFFER_SIZE => BUFFER_SIZE,
      FULLPACKET  => '0'
    )
    port map (
      clk => clk,
      rst => rst,

      packet_size => open,

      flit_in_data  => ring_muxed_data,
      flit_in_last  => ring_muxed_last,
      flit_in_valid => ring_muxed_valid,
      flit_in_ready => ring_muxed_ready,

      flit_out_data  => ring_out0_data,
      flit_out_last  => ring_out0_last,
      flit_out_valid => ring_out0_valid,
      flit_out_ready => ring_out0_ready
    );

  u_buffer1 : riscv_dii_buffer
    generic map (
      XLEN        => XLEN,
      BUFFER_SIZE => BUFFER_SIZE,
      FULLPACKET  => '0'
    )
    port map (
      clk => clk,
      rst => rst,

      packet_size => open,

      flit_in_data  => ring_fwd1_data,
      flit_in_last  => ring_fwd1_last,
      flit_in_valid => ring_fwd1_valid,
      flit_in_ready => ring_fwd1_ready,

      flit_out_data  => ring_out1_data,
      flit_out_last  => ring_out1_last,
      flit_out_valid => ring_out1_valid,
      flit_out_ready => ring_out1_ready
    );
end RTL;
