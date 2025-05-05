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
--              Master Slave Interface Tesbench                               --
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
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

use work.peripheral_dbg_pu_riscv_pkg.all;

entity peripheral_dbg_synthesis is
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
    HCLK    : in  std_logic;
    HRESETn : in  std_logic;

    -- AHB Master Interface Signals
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
    dbg_HRESP     : in  std_logic
  );
end peripheral_dbg_synthesis;

architecture rtl of peripheral_dbg_synthesis is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dbg_pu_riscv_top_tl
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
  -- Variables
  ------------------------------------------------------------------------------

  -- AHB4

  -- JTAG signals
  signal tl_tck_i : std_logic;
  signal tl_tdi_i : std_logic;
  signal tl_tdo_o : std_logic;

  -- TAP states
  signal tl_biur_i        : std_logic;  -- TestLogicReset
  signal tl_shift_dr_i   : std_logic;
  signal tl_pause_dr_i   : std_logic;
  signal tl_update_dr_i  : std_logic;
  signal tl_capture_dr_i : std_logic;

  -- Instructions
  signal tl_debug_select_i : std_logic;

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
  signal tl_cpu_clk_i   : std_logic;
  signal tl_cpu_rstn_i  : std_logic;
  signal tl_cpu_addr_o  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_ADDR_WIDTH-1 downto 0);
  signal tl_cpu_data_i  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
  signal tl_cpu_data_o  : xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
  signal tl_cpu_bp_i    : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal tl_cpu_stall_o : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal tl_cpu_stb_o   : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal tl_cpu_we_o    : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
  signal tl_cpu_ack_i   : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

begin

  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- DUT AHB4
  dbg_pu_riscv_top_tl : peripheral_dbg_pu_riscv_top_tl
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
      tck_i => tl_tck_i,
      tdi_i => tl_tck_i,
      tdo_o => tl_tck_i,

      -- TAP states
      tlr_i        => tl_biur_i,
      shift_dr_i   => tl_shift_dr_i,
      pause_dr_i   => tl_pause_dr_i,
      update_dr_i  => tl_update_dr_i,
      capture_dr_i => tl_capture_dr_i,

      -- Instructions
      debug_select_i => tl_debug_select_i,

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

      int_o => int_o,

      -- CPU/Thread debug ports
      cpu_clk_i   => tl_cpu_clk_i,
      cpu_rstn_i  => tl_cpu_rstn_i,
      cpu_addr_o  => tl_cpu_addr_o,
      cpu_data_i  => tl_cpu_data_i,
      cpu_data_o  => tl_cpu_data_o,
      cpu_bp_i    => tl_cpu_bp_i,
      cpu_stall_o => tl_cpu_stall_o,
      cpu_stb_o   => tl_cpu_stb_o,
      cpu_we_o    => tl_cpu_we_o,
      cpu_ack_i   => tl_cpu_ack_i
    );
end rtl;
