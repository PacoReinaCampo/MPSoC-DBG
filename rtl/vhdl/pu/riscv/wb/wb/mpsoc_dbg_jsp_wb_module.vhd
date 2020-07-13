-- Converted from rtl/verilog/wb/mpsoc_dbg_jsp_wb_module.sv
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

entity mpsoc_dbg_jsp_wb_module is
  generic (
    DBG_JSP_DATAREG_LEN : integer := 64
    );
  port (
    rst_i : in std_logic;

    -- JTAG signals
    tck_i        : in  std_logic;
    tdi_i        : in  std_logic;
    module_tdo_o : out std_logic;

    -- TAP states
    capture_dr_i : in std_logic;
    shift_dr_i   : in std_logic;
    update_dr_i  : in std_logic;

    data_register_i : in  std_logic_vector(DBG_JSP_DATAREG_LEN-1 downto 0);  -- the data register is at top level, shared between all modules
    module_select_i : in  std_logic;
    top_inhibit_o   : out std_logic;

    -- WISHBONE slave interface
    wb_clk_i : in  std_logic;
    wb_rst_i : in  std_logic;
    wb_cyc_i : in  std_logic;
    wb_stb_i : in  std_logic;
    wb_we_i  : in  std_logic;
    wb_adr_i : in  std_logic_vector(2 downto 0);
    wb_dat_i : in  std_logic_vector(7 downto 0);
    wb_dat_o : out std_logic_vector(7 downto 0);
    wb_ack_o : out std_logic;
    wb_err_o : out std_logic;
    int_o    : out std_logic
    );
end mpsoc_dbg_jsp_wb_module;

architecture RTL of mpsoc_dbg_jsp_wb_module is
  component mpsoc_dbg_jsp_module_core
    generic (
      DBG_JSP_DATAREG_LEN : integer := 64
      );
    port (
      rst_i : in std_logic;

      -- JTAG signals
      tck_i        : in  std_logic;
      tdi_i        : in  std_logic;
      module_tdo_o : out std_logic;

      -- TAP states
      capture_dr_i : in std_logic;
      shift_dr_i   : in std_logic;
      update_dr_i  : in std_logic;

      data_register_i : in  std_logic_vector(DBG_JSP_DATAREG_LEN-1 downto 0);  -- the data register is at top level, shared between all modules
      module_select_i : in  std_logic;
      top_inhibit_o   : out std_logic;

      -- JSP BIU interface
      biu_clk             : out std_logic;
      biu_rst             : out std_logic;
      biu_di              : out std_logic_vector(7 downto 0);  -- data towards BIU
      biu_do              : in  std_logic_vector(7 downto 0);  -- data from BIU
      biu_space_available : in  std_logic_vector(3 downto 0);
      biu_bytes_available : in  std_logic_vector(3 downto 0);
      biu_rd_strobe       : out std_logic;  -- Indicates that the BIU should ACK last read operation + start another
      biu_wr_strobe       : out std_logic  -- Indicates BIU should latch input + begin a write operation
      );
  end component;

  component mpsoc_dbg_jsp_wb_biu
    port (
      -- Debug interface signals
      tck_i             : in  std_logic;
      rst_i             : in  std_logic;
      data_i            : in  std_logic_vector(7 downto 0);
      data_o            : out std_logic_vector(7 downto 0);
      bytes_available_o : out std_logic_vector(3 downto 0);
      bytes_free_o      : out std_logic_vector(3 downto 0);
      rd_strobe_i       : in  std_logic;
      wr_strobe_i       : in  std_logic;

      -- Wishbone signals
      wb_clk_i : in  std_logic;
      wb_rst_i : in  std_logic;
      wb_cyc_i : in  std_logic;
      wb_stb_i : in  std_logic;
      wb_we_i  : in  std_logic;
      wb_adr_i : in  std_logic_vector(2 downto 0);
      wb_dat_i : in  std_logic_vector(7 downto 0);
      wb_dat_o : out std_logic_vector(7 downto 0);
      wb_ack_o : out std_logic;
      wb_err_o : out std_logic;

      int_o : out std_logic
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal biu_clk             : std_logic;
  signal biu_rst             : std_logic;
  signal biu_di              : std_logic_vector(7 downto 0);
  signal biu_do              : std_logic_vector(7 downto 0);
  signal biu_bytes_available : std_logic_vector(3 downto 0);
  signal biu_space_available : std_logic_vector(3 downto 0);
  signal biu_rd_strobe       : std_logic;
  signal biu_wr_strobe       : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  --Hookup JSP Debug Core
  jsp_core_inst : mpsoc_dbg_jsp_module_core
    generic map (
      DBG_JSP_DATAREG_LEN => DBG_JSP_DATAREG_LEN
      )
    port map (
      rst_i => rst_i,

      -- JTAG signals
      tck_i        => tck_i,
      tdi_i        => tdi_i,
      module_tdo_o => module_tdo_o,

      -- TAP states
      capture_dr_i => capture_dr_i,
      shift_dr_i   => shift_dr_i,
      update_dr_i  => update_dr_i,

      data_register_i => data_register_i,  -- the data register is at top level, shared between all modules
      module_select_i => module_select_i,
      top_inhibit_o   => top_inhibit_o,

      -- JSP BIU interface
      biu_clk             => biu_clk,
      biu_rst             => biu_rst,
      biu_di              => biu_di,    -- data towards BIU
      biu_do              => biu_do,    -- data from BIU
      biu_space_available => biu_space_available,
      biu_bytes_available => biu_bytes_available,
      biu_rd_strobe       => biu_rd_strobe,  -- Indicates that the BIU should ACK last read operation + start another
      biu_wr_strobe       => biu_wr_strobe  -- Indicates BIU should latch input + begin a write operation
      );

  --Hookup JSP Wishbone Interface
  jsp_biu_inst : mpsoc_dbg_jsp_wb_biu
    port map (
      -- Debug interface signals
      tck_i             => biu_clk,
      rst_i             => biu_rst,
      data_i            => biu_di,
      data_o            => biu_do,
      bytes_available_o => biu_bytes_available,
      bytes_free_o      => biu_space_available,
      rd_strobe_i       => biu_rd_strobe,
      wr_strobe_i       => biu_wr_strobe,

      -- Wishbone slave signals
      wb_clk_i => wb_clk_i,
      wb_rst_i => wb_rst_i,
      wb_cyc_i => wb_cyc_i,
      wb_stb_i => wb_stb_i,
      wb_we_i  => wb_we_i,
      wb_adr_i => wb_adr_i,
      wb_dat_i => wb_dat_i,
      wb_dat_o => wb_dat_o,
      wb_ack_o => wb_ack_o,
      wb_err_o => wb_err_o,

      int_o => int_o
      );
end RTL;
