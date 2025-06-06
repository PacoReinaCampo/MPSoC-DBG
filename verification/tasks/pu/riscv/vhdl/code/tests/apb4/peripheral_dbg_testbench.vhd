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
--              WishBone Bus Interface                                        --
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
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.peripheral_dbg_pu_riscv_pkg.all;

entity peripheral_dbg_testbench is
end peripheral_dbg_testbench;

architecture rtl of peripheral_dbg_testbench is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dbg_pu_riscv_top_apb4
    generic (
      X              : integer := 2;
      Y              : integer := 2;
      Z              : integer := 2;
      CORES_PER_TILE : integer := 4;
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
      tlr_i        : in std_logic;      -- TestLogicReset
      shift_dr_i   : in std_logic;
      pause_dr_i   : in std_logic;
      update_dr_i  : in std_logic;
      capture_dr_i : in std_logic;

      -- Instructions
      debug_select_i : in std_logic;

      -- AHB Master Interface Signals
      HCLK          : in  std_logic;
      HRESETn       : in  std_logic;
      dbg_HSEL      : out std_logic;
      dbg_HADDR     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      dbg_HWDATA    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      dbg_HRDATA    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      dbg_HWRITE    : out std_logic;
      dbg_HSIZE     : out std_logic_vector(2 downto 0);
      dbg_HBURST    : out std_logic_vector(2 downto 0);
      dbg_HPROT     : out std_logic_vector(3 downto 0);
      dbg_HTRANS    : out std_logic_vector(1 downto 0);
      dbg_HMASTLOCK : out std_logic;
      dbg_HREADY    : in  std_logic;
      dbg_HRESP     : in  std_logic;

      -- APB Slave Interface Signals (JTAG Serial Port)
      PRESETn     : in  std_logic;
      PCLK        : in  std_logic;
      jsp_PSEL    : in  std_logic;
      jsp_PENABLE : in  std_logic;
      jsp_PWRITE  : in  std_logic;
      jsp_PADDR   : in  std_logic_vector(2 downto 0);
      jsp_PWDATA  : in  std_logic_vector(7 downto 0);
      jsp_PRDATA  : out std_logic_vector(7 downto 0);
      jsp_PREADY  : out std_logic;
      jsp_PSLVERR : out std_logic;

      int_o : out std_logic;

      -- CPU/Thread debug ports
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

  ------------------------------------------------------------------------------
  --  Constants
  ------------------------------------------------------------------------------
  constant X : integer := 2;
  constant Y : integer := 2;
  constant Z : integer := 2;

  constant CORES_PER_TILE : integer := 4;

  constant ADDR_WIDTH : integer := 32;
  constant DATA_WIDTH : integer := 32;

  constant CPU_ADDR_WIDTH : integer := 32;
  constant CPU_DATA_WIDTH : integer := 32;

  constant DATAREG_LEN : integer := 64;

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------

  -- APB4

  -- JTAG signals
  signal apb4_tck_i : std_logic;
  signal apb4_tdi_i : std_logic;
  signal apb4_tdo_o : std_logic;

  -- TAP states
  signal apb4_tlr_i        : std_logic;  -- TestLogicReset
  signal apb4_shift_dr_i   : std_logic;
  signal apb4_pause_dr_i   : std_logic;
  signal apb4_update_dr_i  : std_logic;
  signal apb4_capture_dr_i : std_logic;

  -- Instructions
  signal apb4_debug_select_i : std_logic;

  -- AHB Master Interface Signals
  signal HCLK          : std_logic;
  signal HRESETn       : std_logic;
  signal dbg_HSEL      : std_logic;
  signal dbg_HADDR     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal dbg_HWDATA    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal dbg_HRDATA    : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal dbg_HWRITE    : std_logic;
  signal dbg_HSIZE     : std_logic_vector(2 downto 0);
  signal dbg_HBURST    : std_logic_vector(2 downto 0);
  signal dbg_HPROT     : std_logic_vector(3 downto 0);
  signal dbg_HTRANS    : std_logic_vector(1 downto 0);
  signal dbg_HMASTLOCK : std_logic;
  signal dbg_HREADY    : std_logic;
  signal dbg_HRESP     : std_logic;

  -- APB Slave Interface Signals (JTAG Serial Port)
  signal PRESETn     : std_logic;
  signal PCLK        : std_logic;
  signal jsp_PSEL    : std_logic;
  signal jsp_PENABLE : std_logic;
  signal jsp_PWRITE  : std_logic;
  signal jsp_PADDR   : std_logic_vector(2 downto 0);
  signal jsp_PWDATA  : std_logic_vector(7 downto 0);
  signal jsp_PRDATA  : std_logic_vector(7 downto 0);
  signal jsp_PREADY  : std_logic;
  signal jsp_PSLVERR : std_logic;

  signal int_o : std_logic;

  -- CPU/Thread debug ports
  signal apb4_cpu_clk_i   : std_logic;
  signal apb4_cpu_rstn_i  : std_logic;
  signal apb4_cpu_addr_o  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_ADDR_WIDTH-1 downto 0);
  signal apb4_cpu_data_i  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
  signal apb4_cpu_data_o  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
  signal apb4_cpu_bp_i    : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal apb4_cpu_stall_o : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal apb4_cpu_stb_o   : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal apb4_cpu_we_o    : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal apb4_cpu_ack_i   : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

begin

  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- DUT APB4
  dbg_pu_riscv_top_apb4 : peripheral_dbg_pu_riscv_top_apb4
    generic map (
      X              => X,
      Y              => Y,
      Z              => Z,
      CORES_PER_TILE => CORES_PER_TILE,

      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH,

      CPU_ADDR_WIDTH => CPU_ADDR_WIDTH,
      CPU_DATA_WIDTH => CPU_ADDR_WIDTH,

      DATAREG_LEN => DATAREG_LEN
      )
    port map (
      -- JTAG signals
      tck_i => apb4_tck_i,
      tdi_i => apb4_tck_i,
      tdo_o => apb4_tck_i,

      -- TAP states
      tlr_i        => apb4_tlr_i,
      shift_dr_i   => apb4_shift_dr_i,
      pause_dr_i   => apb4_pause_dr_i,
      update_dr_i  => apb4_update_dr_i,
      capture_dr_i => apb4_capture_dr_i,

      -- Instructions
      debug_select_i => apb4_debug_select_i,

      -- AHB Master Interface Signals
      HCLK          => HCLK,
      HRESETn       => HRESETn,
      dbg_HSEL      => dbg_HSEL,
      dbg_HADDR     => dbg_HADDR,
      dbg_HWDATA    => dbg_HWDATA,
      dbg_HRDATA    => dbg_HRDATA,
      dbg_HWRITE    => dbg_HWRITE,
      dbg_HSIZE     => dbg_HSIZE,
      dbg_HBURST    => dbg_HBURST,
      dbg_HPROT     => dbg_HPROT,
      dbg_HTRANS    => dbg_HTRANS,
      dbg_HMASTLOCK => dbg_HMASTLOCK,
      dbg_HREADY    => dbg_HREADY,
      dbg_HRESP     => dbg_HRESP,

      -- APB Slave Interface Signals (JTAG Serial Port)
      PRESETn     => PRESETn,
      PCLK        => PCLK,
      jsp_PSEL    => jsp_PSEL,
      jsp_PENABLE => jsp_PENABLE,
      jsp_PWRITE  => jsp_PWRITE,
      jsp_PADDR   => jsp_PADDR,
      jsp_PWDATA  => jsp_PWDATA,
      jsp_PRDATA  => jsp_PRDATA,
      jsp_PREADY  => jsp_PREADY,
      jsp_PSLVERR => jsp_PSLVERR,
      int_o       => int_o,

      -- CPU/Thread debug ports
      cpu_clk_i   => apb4_cpu_clk_i,
      cpu_rstn_i  => apb4_cpu_rstn_i,
      cpu_addr_o  => apb4_cpu_addr_o,
      cpu_data_i  => apb4_cpu_data_i,
      cpu_data_o  => apb4_cpu_data_o,
      cpu_bp_i    => apb4_cpu_bp_i,
      cpu_stall_o => apb4_cpu_stall_o,
      cpu_stb_o   => apb4_cpu_stb_o,
      cpu_we_o    => apb4_cpu_we_o,
      cpu_ack_i   => apb4_cpu_ack_i
    );
end rtl;
