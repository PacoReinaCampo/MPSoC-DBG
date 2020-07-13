-- Converted from bench/verilog/regression/mpsoc_dbg_testbench.sv
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
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_testbench is
end mpsoc_dbg_testbench;

architecture RTL of mpsoc_dbg_testbench is
  component mpsoc_dbg_top_wb
    generic (
      X : integer := 2;
      Y : integer := 2;
      Z : integer := 2;

      CORES_PER_TILE : integer := 1;

      ADDR_WIDTH : integer := 32;
      DATA_WIDTH : integer := 32;

      CPU_ADDR_WIDTH : integer := 32;
      CPU_DATA_WIDTH : integer := 32;

      DATAREG_LEN : integer := 64
      );
    port (
      -- JTAG signals
      tck_i : in  std_logic;
      tdi_i : in  std_logic;
      tdo_o : out std_logic;

      -- TAP states
      tlr_i        : in std_logic;      --TestLogicReset
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
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant X : integer := 2;
  constant Y : integer := 2;
  constant Z : integer := 2;

  constant CORES_PER_TILE : integer := 4;

  constant ADDR_WIDTH : integer := 32;
  constant DATA_WIDTH : integer := 32;

  constant CPU_ADDR_WIDTH : integer := 32;
  constant CPU_DATA_WIDTH : integer := 32;

  constant DATAREG_LEN : integer := 64;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- WB

  -- JTAG signals
  signal wb_tck_i : std_logic;
  signal wb_tdi_i : std_logic;
  signal wb_tdo_o : std_logic;

  -- TAP states
  signal wb_tlr_i        : std_logic;   --TestLogicReset
  signal wb_shift_dr_i   : std_logic;
  signal wb_pause_dr_i   : std_logic;
  signal wb_update_dr_i  : std_logic;
  signal wb_capture_dr_i : std_logic;

  -- Instructions
  signal wb_debug_select_i : std_logic;

  -- WISHBONE Master Interface Signals
  signal wb_clk_i : std_logic;

  signal wb_cyc_o : std_logic;
  signal wb_stb_o : std_logic;
  signal wb_cti_o : std_logic_vector(2 downto 0);
  signal wb_bte_o : std_logic_vector(1 downto 0);
  signal wb_we_o  : std_logic;
  signal wb_adr_o : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal wb_sel_o : std_logic_vector(DATA_WIDTH/8-1 downto 0);
  signal wb_dat_o : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_dat_i : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal wb_ack_i : std_logic;
  signal wb_err_i : std_logic;

  -- WISHBONE Target Interface Signals (JTAG Serial Port)
  signal wb_jsp_clk_i : std_logic;
  signal wb_jsp_rst_i : std_logic;
  signal wb_jsp_cyc_i : std_logic;
  signal wb_jsp_stb_i : std_logic;
  signal wb_jsp_we_i  : std_logic;
  signal wb_jsp_adr_i : std_logic_vector(2 downto 0);
  signal wb_jsp_dat_o : std_logic_vector(7 downto 0);
  signal wb_jsp_dat_i : std_logic_vector(7 downto 0);
  signal wb_jsp_ack_o : std_logic;
  signal wb_jsp_err_o : std_logic;

  signal jsp_int_o : std_logic;

  --CPU/Thread debug ports
  signal wb_cpu_clk_i   : std_logic;
  signal wb_cpu_rstn_i  : std_logic;
  signal wb_cpu_addr_o  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_ADDR_WIDTH-1 downto 0);
  signal wb_cpu_data_i  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
  signal wb_cpu_data_o  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
  signal wb_cpu_bp_i    : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal wb_cpu_stall_o : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal wb_cpu_stb_o   : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal wb_cpu_we_o    : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal wb_cpu_ack_i   : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --DUT WB
  top_wb : mpsoc_dbg_top_wb
    generic map (
      X => X,
      Y => Y,
      Z => Z,
      CORES_PER_TILE => CORES_PER_TILE,

      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH,

      CPU_ADDR_WIDTH => CPU_ADDR_WIDTH,
      CPU_DATA_WIDTH => CPU_ADDR_WIDTH,

      DATAREG_LEN => DATAREG_LEN
      )
    port map (
      -- JTAG signals
      tck_i => wb_tck_i,
      tdi_i => wb_tdi_i,
      tdo_o => wb_tdo_o,

      -- TAP states
      tlr_i        => wb_tlr_i,
      shift_dr_i   => wb_shift_dr_i,
      pause_dr_i   => wb_pause_dr_i,
      update_dr_i  => wb_update_dr_i,
      capture_dr_i => wb_capture_dr_i,

      -- Instructions
      debug_select_i => wb_debug_select_i,

      -- WISHBONE Master Interface Signals
      wb_clk_i => wb_clk_i,

      wb_cyc_o => wb_clk_i,
      wb_stb_o => wb_stb_o,
      wb_cti_o => wb_cti_o,
      wb_bte_o => wb_bte_o,
      wb_we_o  => wb_we_o,
      wb_adr_o => wb_adr_o,
      wb_sel_o => wb_sel_o,
      wb_dat_o => wb_dat_o,
      wb_dat_i => wb_dat_i,
      wb_ack_i => wb_ack_i,
      wb_err_i => wb_err_i,

      -- WISHBONE Target Interface Signals (JTAG Serial Port)
      wb_jsp_clk_i => wb_jsp_clk_i,
      wb_jsp_rst_i => wb_jsp_rst_i,
      wb_jsp_cyc_i => wb_jsp_cyc_i,
      wb_jsp_stb_i => wb_jsp_stb_i,
      wb_jsp_we_i  => wb_jsp_we_i,
      wb_jsp_adr_i => wb_jsp_adr_i,
      wb_jsp_dat_o => wb_jsp_dat_o,
      wb_jsp_dat_i => wb_jsp_dat_i,
      wb_jsp_ack_o => wb_jsp_ack_o,
      wb_jsp_err_o => wb_jsp_err_o,

      jsp_int_o => jsp_int_o,

      --CPU/Thread debug ports
      cpu_clk_i   => wb_cpu_clk_i,
      cpu_rstn_i  => wb_cpu_rstn_i,
      cpu_addr_o  => wb_cpu_addr_o,
      cpu_data_i  => wb_cpu_data_i,
      cpu_data_o  => wb_cpu_data_o,
      cpu_bp_i    => wb_cpu_bp_i,
      cpu_stall_o => wb_cpu_stall_o,
      cpu_stb_o   => wb_cpu_stb_o,
      cpu_we_o    => wb_cpu_we_o,
      cpu_ack_i   => wb_cpu_ack_i
      );
end RTL;
