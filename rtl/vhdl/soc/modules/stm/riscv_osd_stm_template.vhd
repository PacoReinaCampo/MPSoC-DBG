-- Converted from rtl/verilog/modules/template/riscv_osd_stm_template.sv
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

entity riscv_osd_stm_template is
  generic (
    XLEN     : integer := 64;
    VALWIDTH : integer := 2
  );
  port (
    -- the address width of the core register file
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
end riscv_osd_stm_template;

architecture RTL of riscv_osd_stm_template is
  component riscv_osd_stm
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      MAX_REG_SIZE : integer := 64;

      VALWIDTH : integer := 2
    );
    port (
      -- the address width of the core register file
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

      trace_valid : in std_logic;
      trace_id    : in std_logic_vector(XLEN-1 downto 0);
      trace_value : in std_logic_vector(VALWIDTH-1 downto 0)
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal trace_valid : std_logic;
  signal trace_id    : std_logic_vector(XLEN-1 downto 0);
  signal trace_value : std_logic_vector(VALWIDTH-1 downto 0);

  signal trace_reg_enable : std_logic;
  signal trace_reg_addr   : std_logic_vector(REG_ADDR_WIDTH-1 downto 0);

  signal r3_copy : std_logic_vector(VALWIDTH-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  osd_stm : riscv_osd_stm
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      MAX_REG_SIZE => MAX_REG_SIZE,

      VALWIDTH => VALWIDTH
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

      trace_valid => trace_valid,
      trace_id    => trace_id,
      trace_value => trace_value
    );

  processing_0 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (trace_port_we = '1' and (trace_port_addr = "00011")) then
        r3_copy <= trace_port_data;
      end if;
    end if;
  end process;

  trace_valid <= trace_port_valid and to_stdlogic(trace_port_insn(31 downto 16) = X"1500") and to_stdlogic(trace_port_insn(15 downto 0) /= X"0000");

  trace_id    <= trace_port_insn;
  trace_value <= r3_copy;
end RTL;
