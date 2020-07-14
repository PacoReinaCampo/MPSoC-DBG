-- Converted from rtl/verilog/modules/common/riscv_osd_scm.sv
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

entity riscv_osd_scm is
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
end riscv_osd_scm;

architecture RTL of riscv_osd_scm is
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

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal reg_request : std_logic;
  signal reg_write   : std_logic;
  signal reg_addr    : std_logic_vector(63 downto 0);
  signal reg_size    : std_logic_vector(1 downto 0);
  signal reg_wdata   : std_logic_vector(MAX_REG_SIZE-1 downto 0);
  signal reg_ack     : std_logic;
  signal reg_err     : std_logic;
  signal reg_rdata   : std_logic_vector(MAX_REG_SIZE-1 downto 0);

  signal rst_vector : std_logic_vector(1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  sys_rst <= rst_vector(0) or rst;
  cpu_rst <= rst_vector(1) or rst;

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

      debug_in_data  => debug_in_data,
      debug_in_last  => debug_in_last,
      debug_in_valid => debug_in_valid,
      debug_in_ready => debug_in_ready,

      debug_out_data  => debug_out_data,
      debug_out_last  => debug_out_last,
      debug_out_valid => debug_out_valid,
      debug_out_ready => debug_out_ready,

      reg_request => reg_request,
      reg_write   => reg_write,
      reg_addr    => reg_addr,
      reg_size    => reg_size,
      reg_wdata   => reg_wdata,
      reg_ack     => reg_ack,
      reg_err     => reg_err,
      reg_rdata   => reg_rdata,

      event_dest => open,
      stall      => open
    );

  processing_0 : process (reg_addr)
  begin
    reg_ack   <= '1';
    reg_rdata <= (others => 'X');
    reg_err   <= '0';

    case (reg_addr) is
      when X"0000000000000200" =>
        reg_rdata <= std_logic_vector(to_unsigned(SYSTEM_VENDOR_ID, MAX_REG_SIZE));
      when X"0000000000000201" =>
        reg_rdata <= std_logic_vector(to_unsigned(SYSTEM_DEVICE_ID, MAX_REG_SIZE));
      when X"0000000000000202" =>
        reg_rdata <= std_logic_vector(to_unsigned(NUM_MODULES, MAX_REG_SIZE));
      when X"0000000000000203" =>
        reg_rdata <= std_logic_vector(to_unsigned(MAX_PKT_LEN, MAX_REG_SIZE));
      when X"0000000000000204" =>
        reg_rdata <= (MAX_REG_SIZE-1 downto 2 => '0') & rst_vector;
      when others =>
        reg_err <= reg_request;
    end case;
  end process;

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        rst_vector <= "00";
      elsif (reg_request = '1' and reg_write = '1' and (reg_addr = X"0000000000000204")) then
        rst_vector <= reg_wdata(1 downto 0);
      end if;
    end if;
  end process;
end RTL;
