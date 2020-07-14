-- Converted from rtl/verilog/modules/template/riscv_osd_ctm_template.sv
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

entity riscv_osd_ctm_template is
  generic (
    XLEN : integer := 64;
    PLEN : integer := 64;

    MAX_REG_SIZE : integer := 64;

    ADDR_WIDTH : integer := 64;
    DATA_WIDTH : integer := 64;

    VALWIDTH : integer := 2
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

    trace_port_insn     : in std_logic_vector(XLEN-1 downto 0);
    trace_port_pc       : in std_logic_vector(XLEN-1 downto 0);
    trace_port_jb       : in std_logic;
    trace_port_jal      : in std_logic;
    trace_port_jr       : in std_logic;
    trace_port_jbtarget : in std_logic_vector(XLEN-1 downto 0);
    trace_port_valid    : in std_logic;
    trace_port_data     : in std_logic_vector(VALWIDTH-1 downto 0);
    trace_port_addr     : in std_logic_vector(4 downto 0);
    trace_port_we       : in std_logic
  );
end riscv_osd_ctm_template;

architecture RTL of riscv_osd_ctm_template is
  component riscv_osd_ctm
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      MAX_REG_SIZE : integer := 64;

      ADDR_WIDTH : integer := 64;
      DATA_WIDTH : integer := 64
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      id : in std_logic_vector(XLEN-1 downto 0);

      debug_in_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      debug_in_last  : in  std_logic;
      debug_in_valid : in  std_logic;
      debug_in_ready : out std_logic;

      debug_out_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      debug_out_last  : out std_logic;
      debug_out_valid : out std_logic;
      debug_out_ready : in  std_logic;

      trace_valid    : in std_logic;
      trace_pc       : in std_logic_vector(ADDR_WIDTH-1 downto 0);
      trace_npc      : in std_logic_vector(ADDR_WIDTH-1 downto 0);
      trace_jal      : in std_logic;
      trace_jalr     : in std_logic;
      trace_branch   : in std_logic;
      trace_load     : in std_logic;
      trace_store    : in std_logic;
      trace_trap     : in std_logic;
      trace_xcpt     : in std_logic;
      trace_mem      : in std_logic;
      trace_csr      : in std_logic;
      trace_br_taken : in std_logic;
      trace_prv      : in std_logic_vector(1 downto 0);
      trace_addr     : in std_logic_vector(ADDR_WIDTH-1 downto 0);
      trace_rdata    : in std_logic_vector(DATA_WIDTH-1 downto 0);
      trace_wdata    : in std_logic_vector(DATA_WIDTH-1 downto 0);
      trace_time     : in std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal trace_valid    : std_logic;
  signal trace_pc       : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal trace_npc      : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal trace_jal      : std_logic;
  signal trace_jalr     : std_logic;
  signal trace_branch   : std_logic;
  signal trace_load     : std_logic;
  signal trace_store    : std_logic;
  signal trace_trap     : std_logic;
  signal trace_xcpt     : std_logic;
  signal trace_mem      : std_logic;
  signal trace_csr      : std_logic;
  signal trace_br_taken : std_logic;
  signal trace_prv      : std_logic_vector(1 downto 0);
  signal trace_addr     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal trace_rdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal trace_wdata    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal trace_time     : std_logic_vector(DATA_WIDTH-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  osd_ctm : riscv_osd_ctm
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      MAX_REG_SIZE => MAX_REG_SIZE,

      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH
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

      trace_valid    => trace_valid,
      trace_pc       => trace_pc,
      trace_npc      => trace_npc,
      trace_jal      => trace_jal,
      trace_jalr     => trace_jalr,
      trace_branch   => trace_branch,
      trace_load     => trace_load,
      trace_store    => trace_store,
      trace_trap     => trace_trap,
      trace_xcpt     => trace_xcpt,
      trace_mem      => trace_mem,
      trace_csr      => trace_csr,
      trace_br_taken => trace_br_taken,
      trace_prv      => trace_prv,
      trace_addr     => trace_addr,
      trace_rdata    => trace_rdata,
      trace_wdata    => trace_wdata,
      trace_time     => trace_time
    );

  trace_valid <= trace_port_valid;
  trace_pc    <= trace_port_pc;
  trace_npc   <= trace_port_jbtarget;
  trace_jal   <= trace_port_jal;
  trace_jalr  <= trace_port_jr;

  trace_branch   <= '0';
  trace_load     <= '0';
  trace_store    <= '0';
  trace_trap     <= '0';
  trace_xcpt     <= '0';
  trace_mem      <= '0';
  trace_csr      <= '0';
  trace_br_taken <= '0';
  trace_prv      <= (others => '0');
  trace_addr     <= (others => '0');
  trace_rdata    <= (others => '0');
  trace_wdata    <= (others => '0');
  trace_time     <= (others => '0');
end RTL;
