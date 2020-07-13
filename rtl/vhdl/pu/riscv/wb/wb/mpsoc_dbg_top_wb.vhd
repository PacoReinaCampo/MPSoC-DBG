-- Converted from rtl/verilog/wb/mpsoc_dbg_top_wb.sv
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
use ieee.math_real.all;

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_top_wb is
  generic (
    X              : integer := 2;
    Y              : integer := 2;
    Z              : integer := 2;
    CORES_PER_TILE : integer := 1;
    ADDR_WIDTH     : integer := 32;
    DATA_WIDTH     : integer := 32;
    CPU_ADDR_WIDTH : integer := 32;
    CPU_DATA_WIDTH : integer := 32;
    DATAREG_LEN    : integer := 64
    );
  port (
    -- JTAG signals
    tck_i : in  std_logic;
    tdi_i : in  std_logic;
    tdo_o : out std_logic;

    -- TAP states
    tlr_i        : in std_logic;        --TestLogicReset
    shift_dr_i   : in std_logic;
    pause_dr_i   : in std_logic;
    update_dr_i  : in std_logic;
    capture_dr_i : in std_logic;

    -- Instructions
    debug_select_i : in std_logic;

    -- WISHBONE Master Interface Signals
    wb_clk_i : in std_logic;

    wb_cyc_o : out std_logic;
    wb_stb_o : out std_logic;
    wb_cti_o : out std_logic_vector(2 downto 0);
    wb_bte_o : out std_logic_vector(1 downto 0);
    wb_we_o  : out std_logic;
    wb_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    wb_sel_o : out std_logic_vector(DATA_WIDTH/8-1 downto 0);
    wb_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_ack_i : in  std_logic;
    wb_err_i : in  std_logic;

    -- WISHBONE Target Interface Signals (JTAG Serial Port)
    wb_jsp_clk_i : in  std_logic;
    wb_jsp_rst_i : in  std_logic;
    wb_jsp_cyc_i : in  std_logic;
    wb_jsp_stb_i : in  std_logic;
    wb_jsp_we_i  : in  std_logic;
    wb_jsp_adr_i : in  std_logic_vector(2 downto 0);
    wb_jsp_dat_o : out std_logic_vector(7 downto 0);
    wb_jsp_dat_i : in  std_logic_vector(7 downto 0);
    wb_jsp_ack_o : out std_logic;
    wb_jsp_err_o : out std_logic;
    jsp_int_o    : out std_logic;

    --CPU/Thread debug ports
    cpu_clk_i   : in  std_logic;
    cpu_rstn_i  : in  std_logic;
    cpu_addr_o  : out xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_ADDR_WIDTH-1 downto 0);
    cpu_data_i  : in  xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
    cpu_data_o  : out xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
    cpu_bp_i    : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    cpu_stall_o : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    cpu_stb_o   : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    cpu_we_o    : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    cpu_ack_i   : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)
    );
end mpsoc_dbg_top_wb;

architecture RTL of mpsoc_dbg_top_wb is
  component mpsoc_dbg_wb_module
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
  end component;

  component mpsoc_dbg_or1k_module
    generic (
      X                    : integer := 2;
      Y                    : integer := 2;
      Z                    : integer := 2;
      CORES_PER_TILE       : integer := 1;
      CPU_ADDR_WIDTH       : integer := 32;
      CPU_DATA_WIDTH       : integer := 32;
      DBG_OR1K_DATAREG_LEN : integer := 64
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

      data_register_i : in  std_logic_vector(DBG_OR1K_DATAREG_LEN-1 downto 0);
      module_select_i : in  std_logic;
      top_inhibit_o   : out std_logic;

      -- Interface to debug unit
      cpu_clk_i   : in  std_logic;
      cpu_rstn_i  : in  std_logic;
      cpu_addr_o  : out xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_ADDR_WIDTH-1 downto 0);
      cpu_data_i  : in  xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
      cpu_data_o  : out xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
      cpu_bp_i    : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
      cpu_stall_o : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
      cpu_stb_o   : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
      cpu_we_o    : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
      cpu_ack_i   : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)
      );
  end component;

  component mpsoc_dbg_jsp_wb_module
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
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  -- Chains
  constant TOP_BUSIF_DEBUG_MODULE  : std_logic_vector(1 downto 0) := "00";
  constant TOP_CPU_DEBUG_MODULE    : std_logic_vector(1 downto 0) := "01";
  constant TOP_JSP_DEBUG_MODULE    : std_logic_vector(1 downto 0) := "10";
  constant TOP_RESERVED_DBG_MODULE : std_logic_vector(1 downto 0) := "11";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal tdo_busif : std_logic;
  signal tdo_cpu   : std_logic;
  signal tdo_jsp   : std_logic;

  -- Registers
  signal input_shift_reg : std_logic_vector(DBG_TOP_DATAREG_LEN-1 downto 0);  -- Main chain shift register, pushed into each module
  signal module_id_reg   : std_logic_vector(1 downto 0);  -- Module selection register

  -- Control signals
  signal select_cmd     : std_logic;  -- True when the command (registered at Update_DR) is for top level/module selection
  signal module_id_in   : std_logic_vector(DBG_TOP_MODULE_ID_LENGTH-1 downto 0);  -- The part of the input_shift_register to be used as the module select data
  signal module_selects : std_logic_vector(DBG_TOP_MAX_MODULES-1 downto 0);  -- Select signals for the individual modules, number of modules = 4 (CPU, JSP, Bus, reserved)
  signal select_inhibit : std_logic;  -- OR of inhibit signals from sub-modules, prevents latching of a new module ID
  signal module_inhibit : std_logic_vector(DBG_TOP_MAX_MODULES-1 downto 0);  -- signals to allow submodules to prevent top level from latching new module ID

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Combinatorial assignments
  select_cmd   <= input_shift_reg(DBG_TOP_DATAREG_LEN-1);
  module_id_in <= input_shift_reg(DBG_TOP_DATAREG_LEN-2 downto DBG_TOP_DATAREG_LEN-DBG_TOP_MODULE_ID_LENGTH-1);

  -- Module select register and select signals
  processing_0 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      module_id_reg <= (others => '0');
    elsif (rising_edge(tck_i)) then
      if (debug_select_i = '1' and select_cmd = '1' and update_dr_i = '1' and select_inhibit = '0') then  -- Chain select
        module_id_reg <= module_id_in;
      end if;
    end if;
  end process;

  processing_1 : process (module_id_reg)
  begin
    module_selects                                      <= (others => '0');
    module_selects(to_integer(unsigned(module_id_reg))) <= '1';
  end process;

  -- Data input shift register
  processing_2 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      input_shift_reg <= (others => '0');
    elsif (rising_edge(tck_i)) then
      if (debug_select_i = '1' and shift_dr_i = '1') then
        input_shift_reg <= (tdi_i & input_shift_reg(DBG_TOP_DATAREG_LEN-1 downto 1));
      end if;
    end if;
  end process;

  --Wishbone debug module instantiation
  i_dbg_wb : mpsoc_dbg_wb_module
    generic map (
      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH
      )
    port map (
      -- JTAG signals
      tlr_i        => tlr_i,
      tck_i        => tck_i,
      module_tdo_o => tdo_busif,
      tdi_i        => tdi_i,

      -- TAP states
      capture_dr_i => capture_dr_i,
      shift_dr_i   => shift_dr_i,
      update_dr_i  => update_dr_i,

      data_register_i => input_shift_reg(DBG_TOP_DATAREG_LEN-1 downto DBG_TOP_DATAREG_LEN-DBG_WB_DATAREG_LEN),
      module_select_i => module_selects(DBG_TOP_BUSIF_DEBUG_MODULE),
      top_inhibit_o   => module_inhibit(DBG_TOP_BUSIF_DEBUG_MODULE),

      -- WISHBONE common signals
      wb_clk_i => wb_clk_i,

      -- WISHBONE master interface
      wb_adr_o => wb_adr_o,
      wb_dat_o => wb_dat_o,
      wb_dat_i => wb_dat_i,
      wb_cyc_o => wb_cyc_o,
      wb_stb_o => wb_stb_o,
      wb_sel_o => wb_sel_o,
      wb_we_o  => wb_we_o,
      wb_ack_i => wb_ack_i,
      wb_err_i => wb_err_i,
      wb_cti_o => wb_cti_o,
      wb_bte_o => wb_bte_o
      );

  i_dbg_cpu_or1k : mpsoc_dbg_or1k_module
    generic map (
      X              => X,
      Y              => Z,
      Z              => Z,
      CORES_PER_TILE => CORES_PER_TILE
      )
    port map (
      -- JTAG signals
      tck_i        => tck_i,
      module_tdo_o => tdo_cpu,
      tdi_i        => tdi_i,

      -- TAP states
      tlr_i        => tlr_i,
      capture_dr_i => capture_dr_i,
      shift_dr_i   => shift_dr_i,
      update_dr_i  => update_dr_i,

      data_register_i => input_shift_reg(DBG_TOP_DATAREG_LEN-1 downto DBG_TOP_DATAREG_LEN-DBG_OR1K_DATAREG_LEN),
      module_select_i => module_selects(DBG_TOP_CPU_DEBUG_MODULE),
      top_inhibit_o   => module_inhibit(DBG_TOP_CPU_DEBUG_MODULE),

      -- CPU signals
      cpu_rstn_i  => cpu_rstn_i,
      cpu_clk_i   => cpu_clk_i,
      cpu_addr_o  => cpu_addr_o,
      cpu_data_i  => cpu_data_i,
      cpu_data_o  => cpu_data_o,
      cpu_bp_i    => cpu_bp_i,
      cpu_stall_o => cpu_stall_o,
      cpu_stb_o   => cpu_stb_o,
      cpu_we_o    => cpu_we_o,
      cpu_ack_i   => cpu_ack_i
      );

  i_dbg_jsp : mpsoc_dbg_jsp_wb_module
    port map (
      rst_i => tlr_i,

      -- JTAG signals
      tck_i        => tck_i,
      module_tdo_o => tdo_jsp,
      tdi_i        => tdi_i,

      -- TAP states
      capture_dr_i => capture_dr_i,
      shift_dr_i   => shift_dr_i,
      update_dr_i  => update_dr_i,

      data_register_i => input_shift_reg(DBG_TOP_DATAREG_LEN-1 downto DBG_TOP_DATAREG_LEN-DBG_JSP_DATAREG_LEN),
      module_select_i => module_selects(DBG_TOP_JSP_DEBUG_MODULE),
      top_inhibit_o   => module_inhibit(DBG_TOP_JSP_DEBUG_MODULE),

      -- WISHBONE connections
      wb_clk_i => wb_jsp_clk_i,
      wb_rst_i => wb_jsp_rst_i,
      wb_cyc_i => wb_jsp_cyc_i,
      wb_stb_i => wb_jsp_stb_i,
      wb_we_i  => wb_jsp_we_i,
      wb_adr_i => wb_jsp_adr_i,
      wb_dat_i => wb_jsp_dat_i,
      wb_dat_o => wb_jsp_dat_o,
      wb_ack_o => wb_jsp_ack_o,
      wb_err_o => wb_jsp_err_o,
      int_o    => jsp_int_o
      );

  module_inhibit(DBG_TOP_RESERVED_DBG_MODULE) <= '0';

  select_inhibit <= reduce_or(module_inhibit);

  -- TDO output MUX
  processing_3 : process (module_id_reg)
  begin
    case (module_id_reg) is
      when TOP_BUSIF_DEBUG_MODULE =>
        tdo_o <= tdo_busif;
      when TOP_CPU_DEBUG_MODULE =>
        tdo_o <= tdo_cpu;
      when TOP_JSP_DEBUG_MODULE =>
        tdo_o <= tdo_jsp;
      when others =>
        tdo_o <= '0';
    end case;
  end process;
end RTL;
