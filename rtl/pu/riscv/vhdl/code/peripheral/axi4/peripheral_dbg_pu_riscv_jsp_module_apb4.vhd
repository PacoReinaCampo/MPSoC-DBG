--------------------------------------------------------------------------------
--                                            __ _      _     _               --
--                                           / _(_)    | |   | |              --
--                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              --
--               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              --
--              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              --
--               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              --
--                  | |                                                       --
--                  |_|                                                       --
--                                                                            --
--                                                                            --
--              MPSoC-RISCV CPU                                               --
--              Degub Interface                                               --
--              AMBA4 AHB-Lite Bus Interface                                  --
--                                                                            --
--------------------------------------------------------------------------------

-- Copyright (c) 2018-2019 by the author(s)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
--------------------------------------------------------------------------------
-- Author(s):
--   Nathan Yawn <nathan.yawn@opencores.org>
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.peripheral_dbg_pu_riscv_pkg.all;

entity peripheral_dbg_pu_riscv_jsp_module_apb4 is
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

    -- the data register is at top level, shared between all modules
    data_register_i : in  std_logic_vector(DBG_JSP_DATAREG_LEN-1 downto 0);
    module_select_i : in  std_logic;
    top_inhibit_o   : out std_logic;

    -- AMBA APB interface
    PRESETn : in std_logic;
    PCLK    : in std_logic;

    PSEL    : in  std_logic;
    PENABLE : in  std_logic;
    PWRITE  : in  std_logic;
    PADDR   : in  std_logic_vector(2 downto 0);
    PWDATA  : in  std_logic_vector(7 downto 0);
    PRDATA  : out std_logic_vector(7 downto 0);
    PREADY  : out std_logic;
    PSLVERR : out std_logic;

    int_o : out std_logic
    );
end peripheral_dbg_pu_riscv_jsp_module_apb4;

architecture rtl of peripheral_dbg_pu_riscv_jsp_module_apb4 is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dbg_pu_riscv_jsp_module_core
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

      -- JSP TILELINK interface
      biu_clk             : out std_logic;
      biu_rst             : out std_logic;
      biu_di              : out std_logic_vector(7 downto 0);  -- data towards TILELINK
      biu_do              : in  std_logic_vector(7 downto 0);  -- data from TILELINK
      biu_space_available : in  std_logic_vector(3 downto 0);
      biu_bytes_available : in  std_logic_vector(3 downto 0);
      biu_rd_strobe       : out std_logic;  -- Indicates that the TILELINK should ACK last read operation + start another
      biu_wr_strobe       : out std_logic  -- Indicates TILELINK should latch input + begin a write operation
      );
  end component;

  component peripheral_dbg_pu_riscv_jsp_axi4_tl
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

      -- APB signals
      PRESETn : in std_logic;
      PCLK    : in std_logic;

      PSEL    : in  std_logic;
      PENABLE : in  std_logic;
      PWRITE  : in  std_logic;
      PADDR   : in  std_logic_vector(2 downto 0);
      PWDATA  : in  std_logic_vector(7 downto 0);
      PRDATA  : out std_logic_vector(7 downto 0);
      PREADY  : out std_logic;
      PSLVERR : out std_logic;

      int_o : out std_logic
      );
  end component;

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal biu_clk             : std_logic;
  signal biu_rst             : std_logic;
  signal biu_di              : std_logic_vector(7 downto 0);
  signal biu_do              : std_logic_vector(7 downto 0);
  signal biu_bytes_available : std_logic_vector(3 downto 0);
  signal biu_space_available : std_logic_vector(3 downto 0);
  signal biu_rd_strobe       : std_logic;
  signal biu_wr_strobe       : std_logic;

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- Hookup JSP Debug Core
  jsp_core_inst : peripheral_dbg_pu_riscv_jsp_module_core
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

      -- JSP TILELINK interface
      biu_clk             => biu_clk,
      biu_rst             => biu_rst,
      biu_di              => biu_di,    -- data towards TILELINK
      biu_do              => biu_do,    -- data from TILELINK
      biu_space_available => biu_space_available,
      biu_bytes_available => biu_bytes_available,
      biu_rd_strobe       => biu_rd_strobe,  -- Indicates that the TILELINK should ACK last read operation + start another
      biu_wr_strobe       => biu_wr_strobe  -- Indicates TILELINK should latch input + begin a write operation
      );

  -- Hookup JSP APB Interface
  jsp_tl_inst : peripheral_dbg_pu_riscv_jsp_axi4_tl
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

      -- APB signals
      PRESETn => PRESETn,
      PCLK    => PCLK,

      PSEL    => PSEL,
      PENABLE => PENABLE,
      PWRITE  => PWRITE,
      PADDR   => PADDR,
      PWDATA  => PWDATA,
      PRDATA  => PRDATA,
      PREADY  => PREADY,
      PSLVERR => PSLVERR,

      int_o => int_o
      );
end rtl;
