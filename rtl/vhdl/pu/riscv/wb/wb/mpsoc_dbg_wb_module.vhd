-- Converted from rtl/verilog/wb/mpsoc_dbg_wb_module.sv
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
--              WishBone Bus Interface                                        //
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
-- *   Nathan Yawn <nathan.yawn@opencores.org>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_wb_module is
  generic (
    ADDR_WIDTH         : integer := 32;
    DATA_WIDTH         : integer := 32;
    DBG_WB_DATAREG_LEN : integer := 64
    );
  port (
    -- JTAG signals
    tck_i        : in  std_logic;
    module_tdo_o : out std_logic;
    tdi_i        : in  std_logic;

    -- TAP states
    tlr_i        : in std_logic;
    capture_dr_i : in std_logic;
    shift_dr_i   : in std_logic;
    update_dr_i  : in std_logic;

    data_register_i : in  std_logic_vector(DBG_WB_DATAREG_LEN-1 downto 0);  -- the data register is at top level, shared between all modules
    module_select_i : in  std_logic;
    top_inhibit_o   : out std_logic;

    -- WISHBONE master interface
    wb_clk_i : in  std_logic;
    wb_cyc_o : out std_logic;
    wb_stb_o : out std_logic;
    wb_we_o  : out std_logic;
    wb_sel_o : out std_logic_vector(DATA_WIDTH/8-1 downto 0);
    wb_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    wb_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_cti_o : out std_logic_vector(2 downto 0);
    wb_bte_o : out std_logic_vector(1 downto 0);
    wb_ack_i : in  std_logic;
    wb_err_i : in  std_logic
    );
end mpsoc_dbg_wb_module;

architecture RTL of mpsoc_dbg_wb_module is
  component mpsoc_dbg_bus_module_core
    generic (
      --parameter such that these can be pushed down from the higher level
      --higher level will either read these from a package or get them as parameters

      --Data + Address width
      ADDR_WIDTH : integer := 32;
      DATA_WIDTH : integer := 32;

      --Data register size (function of ADDR_WIDTH)
      DATAREG_LEN : integer := 64
      );
    port (
      dbg_clk : in  std_logic;
      dbg_rst : in  std_logic;
      dbg_tdi : in  std_logic;
      dbg_tdo : out std_logic;

      -- TAP states
      capture_dr_i : in std_logic;
      shift_dr_i   : in std_logic;
      update_dr_i  : in std_logic;

      data_register : in  std_logic_vector(DATAREG_LEN-1 downto 0);  -- the data register is at top level, shared between all modules
      module_select : in  std_logic;
      inhibit       : out std_logic;

      --Bus Interface Unit ports
      biu_clk       : out std_logic;
      biu_rst       : out std_logic;    --BIU reset
      biu_di        : out std_logic_vector(DATA_WIDTH-1 downto 0);  --data towards BIU
      biu_do        : in  std_logic_vector(DATA_WIDTH-1 downto 0);  --data from BIU
      biu_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_strb      : out std_logic;
      biu_rw        : out std_logic;
      biu_rdy       : in  std_logic;
      biu_err       : in  std_logic;
      biu_word_size : out std_logic_vector(3 downto 0)
      );
  end component;

  component mpsoc_dbg_wb_biu
    generic (
      LITTLE_ENDIAN : std_logic := '1';
      ADDR_WIDTH    : integer   := 32;
      DATA_WIDTH    : integer   := 32
      );
    port (
      -- Debug interface signals
      biu_clk       : in  std_logic;
      biu_rst       : in  std_logic;
      biu_di        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_do        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      biu_addr      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      biu_strb      : in  std_logic;
      biu_rw        : in  std_logic;
      biu_rdy       : out std_logic;
      biu_err       : out std_logic;
      biu_word_size : in  std_logic_vector(3 downto 0);

      -- Wishbone signals
      wb_clk_i : in  std_logic;
      wb_cyc_o : out std_logic;
      wb_stb_o : out std_logic;
      wb_we_o  : out std_logic;
      wb_cti_o : out std_logic_vector(2 downto 0);
      wb_bte_o : out std_logic_vector(1 downto 0);
      wb_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      wb_sel_o : out std_logic_vector(DATA_WIDTH/8-1 downto 0);
      wb_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      wb_ack_i : in  std_logic;
      wb_err_i : in  std_logic
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal biu_clk       : std_logic;
  signal biu_rst       : std_logic;
  signal biu_do        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_di        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal biu_addr      : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal biu_strb      : std_logic;
  signal biu_rw        : std_logic;
  signal biu_rdy       : std_logic;
  signal biu_err       : std_logic;
  signal biu_word_size : std_logic_vector(3 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --Hookup Bus Debug Core
  bus_module_core_inst : mpsoc_dbg_bus_module_core
    generic map (
      ADDR_WIDTH  => ADDR_WIDTH,
      DATA_WIDTH  => DATA_WIDTH,
      DATAREG_LEN => DBG_WB_DATAREG_LEN
      )
    port map (
      --Debug Module ports
      dbg_rst => tlr_i,
      dbg_clk => tck_i,
      dbg_tdi => tdi_i,
      dbg_tdo => module_tdo_o,

      -- TAP states
      capture_dr_i => capture_dr_i,
      shift_dr_i   => shift_dr_i,
      update_dr_i  => update_dr_i,

      data_register => data_register_i,  --data register from top-level
      module_select => module_select_i,
      inhibit       => top_inhibit_o,

      --Bus Interface Unit ports
      biu_clk       => biu_clk,
      biu_rst       => biu_rst,         --BIU reset
      biu_di        => biu_di,          --data towards BIU
      biu_do        => biu_do,          --data from BIU
      biu_addr      => biu_addr,
      biu_strb      => biu_strb,
      biu_rw        => biu_rw,
      biu_rdy       => biu_rdy,
      biu_err       => biu_err,
      biu_word_size => biu_word_size
      );

  --Hookup Bus Wishbone Interface
  wb_biu_i : mpsoc_dbg_wb_biu
    generic map (
      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH
      )
    port map (
      -- Debug interface signals
      biu_clk       => biu_clk,
      biu_rst       => biu_rst,
      biu_di        => biu_di,
      biu_do        => biu_do,
      biu_addr      => biu_addr,
      biu_strb      => biu_strb,
      biu_rw        => biu_rw,
      biu_rdy       => biu_rdy,
      biu_err       => biu_err,
      biu_word_size => biu_word_size,

      -- Wishbone signals
      wb_clk_i => wb_clk_i,
      wb_cyc_o => wb_cyc_o,
      wb_stb_o => wb_stb_o,
      wb_we_o  => wb_we_o,
      wb_cti_o => wb_cti_o,
      wb_bte_o => wb_bte_o,
      wb_adr_o => wb_adr_o,
      wb_sel_o => wb_sel_o,
      wb_dat_o => wb_dat_o,
      wb_dat_i => wb_dat_i,
      wb_ack_i => wb_ack_i,
      wb_err_i => wb_err_i
      );
end RTL;
