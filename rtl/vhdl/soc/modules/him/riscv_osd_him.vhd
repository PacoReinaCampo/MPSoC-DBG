-- Converted from rtl/verilog/modules/common/riscv_osd_him.sv
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

use work.riscv_mpsoc_pkg.all;

entity riscv_osd_him is
  generic (
    XLEN : integer := 64;

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
end riscv_osd_him;

architecture RTL of riscv_osd_him is
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
  signal dii_ingress_data  : std_logic_vector(XLEN-1 downto 0);
  signal dii_ingress_last  : std_logic;
  signal dii_ingress_valid : std_logic;
  signal dii_ingress_ready : std_logic;

  signal ingress_active : std_logic;
  signal ingress_size   : std_logic_vector(4 downto 0);
  signal ingress_data   : std_logic_vector(XLEN-1 downto 0);

  signal dii_egress_data  : std_logic_vector(XLEN-1 downto 0);
  signal dii_egress_last  : std_logic;
  signal dii_egress_valid : std_logic;
  signal dii_egress_ready : std_logic;

  signal egress_packet_size : std_logic_vector(integer(log2(real(BUFFER_SIZE))) downto 0);

  signal egress_active : std_logic;

  signal egress_data : std_logic_vector(XLEN-1 downto 0);

  signal in_ready : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  ingress_data <= glip_in_data;

  in_ready <= not ingress_active or dii_ingress_ready;

  glip_in_ready <= in_ready;

  dii_ingress_data  <= ingress_data;
  dii_ingress_last  <= ingress_active and to_stdlogic(ingress_size = "00000");
  dii_ingress_valid <= ingress_active and glip_in_valid;

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        ingress_active <= '0';
      elsif (ingress_active = '0') then
        if (glip_in_valid = '1' and in_ready = '1') then
          ingress_size   <= std_logic_vector(unsigned(ingress_data(4 downto 0))-"00001");
          ingress_active <= '1';
        end if;
      elsif (glip_in_valid = '1' and in_ready = '1') then
        ingress_size <= std_logic_vector(unsigned(ingress_size)-"00001");
        if (ingress_size = "00000") then
          ingress_active <= '0';
        end if;
      end if;
    end if;
  end process;

  ingress_buffer : riscv_dii_buffer
    generic map (
      XLEN        => XLEN,
      BUFFER_SIZE => BUFFER_SIZE,
      FULLPACKET  => '0'
    )
    port map (
      clk => clk,
      rst => rst,

      packet_size => open,

      flit_in_data  => dii_ingress_data,
      flit_in_last  => dii_ingress_last,
      flit_in_valid => dii_ingress_valid,
      flit_in_ready => dii_ingress_ready,

      flit_out_data  => dii_out_data,
      flit_out_last  => dii_out_last,
      flit_out_valid => dii_out_valid,
      flit_out_ready => dii_out_ready
      );

  processing_1 : process (egress_active)
  begin
    if (egress_active = '0') then
      egress_data(15 downto integer(log2(real(BUFFER_SIZE)))) <= (others => '0');
      egress_data(integer(log2(real(BUFFER_SIZE))) downto 0)  <= egress_packet_size;
    else
      egress_data <= dii_egress_data;
    end if;
  end process;

  glip_out_data    <= egress_data;
  glip_out_valid   <= dii_egress_valid;
  dii_egress_ready <= egress_active and glip_out_ready;

  processing_2 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        egress_active <= '0';
      elsif (egress_active = '0') then
        if (dii_egress_valid = '1' and glip_out_ready = '1') then
          egress_active <= '1';
        end if;
      elsif (dii_egress_valid = '1' and dii_egress_ready = '1' and dii_egress_last = '1') then
        egress_active <= '0';
      end if;
    end if;
  end process;

  egress_buffer : riscv_dii_buffer
    generic map (
      XLEN        => XLEN,
      BUFFER_SIZE => BUFFER_SIZE,
      FULLPACKET  => '0'
    )
    port map (
      clk => clk,
      rst => rst,

      packet_size => egress_packet_size,

      flit_in_data  => dii_in_data,
      flit_in_last  => dii_in_last,
      flit_in_valid => dii_in_valid,
      flit_in_ready => dii_in_ready,

      flit_out_data  => dii_egress_data,
      flit_out_last  => dii_egress_last,
      flit_out_valid => dii_egress_valid,
      flit_out_ready => dii_egress_ready
      );
end RTL;
