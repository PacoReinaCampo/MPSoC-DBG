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
--              AMBA3 AHB-Lite Bus Interface                                  --
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

entity peripheral_dbg_pu_riscv_module_axi4 is
  generic (
    ADDR_WIDTH          : integer := 32;
    DATA_WIDTH          : integer := 32;
    DBG_AHB_DATAREG_LEN : integer := 64
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

    -- the data register is at top level, shared between all modules
    data_register_i : in  std_logic_vector(DBG_AHB_DATAREG_LEN-1 downto 0);
    module_select_i : in  std_logic;
    top_inhibit_o   : out std_logic;

    -- AHB3 master interface
    HCLK      : in  std_logic;
    HRESETn   : in  std_logic;
    HSEL      : out std_logic;
    HADDR     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    HWDATA    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    HRDATA    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    HWRITE    : out std_logic;
    HSIZE     : out std_logic_vector(2 downto 0);
    HBURST    : out std_logic_vector(2 downto 0);
    HPROT     : out std_logic_vector(3 downto 0);
    HTRANS    : out std_logic_vector(1 downto 0);
    HMASTLOCK : out std_logic;
    HREADY    : in  std_logic;
    HRESP     : in  std_logic
    );
end peripheral_dbg_pu_riscv_module_axi4;

architecture rtl of peripheral_dbg_pu_riscv_module_axi4 is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dbg_pu_riscv_bus_module_core
    generic (
      -- parameter such that these can be pushed down from the higher level
      -- higher level will either read these from a package or get them as parameters

      -- Data + Address width
      ADDR_WIDTH : integer := 32;
      DATA_WIDTH : integer := 32;

      -- Data register size (function of ADDR_WIDTH)
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

      -- Bus Interface Unit ports
      axi4_clk       : out std_logic;
      axi4_rst       : out std_logic;    -- BIU reset
      axi4_di        : out std_logic_vector(DATA_WIDTH-1 downto 0);  -- data towards BIU
      axi4_do        : in  std_logic_vector(DATA_WIDTH-1 downto 0);  -- data from BIU
      axi4_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      axi4_strb      : out std_logic;
      axi4_rw        : out std_logic;
      axi4_rdy       : in  std_logic;
      axi4_err       : in  std_logic;
      axi4_word_size : out std_logic_vector(3 downto 0)
      );
  end component;

  component peripheral_dbg_pu_riscv_axi4_axi4
    generic (
      LITTLE_ENDIAN : std_logic := '1';
      ADDR_WIDTH    : integer   := 32;
      DATA_WIDTH    : integer   := 32
      );
    port (
      -- Debug interface signals
      axi4_clk       : in  std_logic;
      axi4_rst       : in  std_logic;
      axi4_di        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_do        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      axi4_addr      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      axi4_strb      : in  std_logic;
      axi4_rw        : in  std_logic;
      axi4_rdy       : out std_logic;
      axi4_err       : out std_logic;
      axi4_word_size : in  std_logic_vector(3 downto 0);

      -- AHB Master signals
      HCLK      : in  std_logic;
      HRESETn   : in  std_logic;
      HSEL      : out std_logic;
      HADDR     : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      HWDATA    : out std_logic_vector(DATA_WIDTH-1 downto 0);
      HRDATA    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      HWRITE    : out std_logic;
      HSIZE     : out std_logic_vector(2 downto 0);
      HBURST    : out std_logic_vector(2 downto 0);
      HPROT     : out std_logic_vector(3 downto 0);
      HTRANS    : out std_logic_vector(1 downto 0);
      HMASTLOCK : out std_logic;
      HREADY    : in  std_logic;
      HRESP     : in  std_logic
      );
  end component;

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal axi4_clk       : std_logic;
  signal axi4_rst       : std_logic;
  signal axi4_do        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_di        : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal axi4_addr      : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal axi4_strb      : std_logic;
  signal axi4_rw        : std_logic;
  signal axi4_rdy       : std_logic;
  signal axi4_err       : std_logic;
  signal axi4_word_size : std_logic_vector(3 downto 0);

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- Hookup Bus Debug Core
  bus_module_core_inst : peripheral_dbg_pu_riscv_bus_module_core
    generic map (
      ADDR_WIDTH  => ADDR_WIDTH,
      DATA_WIDTH  => DATA_WIDTH,
      DATAREG_LEN => DBG_AHB_DATAREG_LEN
      )
    port map (
      -- Debug Module ports
      dbg_rst => tlr_i,
      dbg_clk => tck_i,
      dbg_tdi => tdi_i,
      dbg_tdo => module_tdo_o,

      -- TAP states
      capture_dr_i => capture_dr_i,
      shift_dr_i   => shift_dr_i,
      update_dr_i  => update_dr_i,

      data_register => data_register_i,  -- data register from top-level
      module_select => module_select_i,
      inhibit       => top_inhibit_o,

      -- Bus Interface Unit ports
      axi4_clk       => axi4_clk,
      axi4_rst       => axi4_rst,         -- BIU reset
      axi4_di        => axi4_di,          -- data towards BIU
      axi4_do        => axi4_do,          -- data from BIU
      axi4_addr      => axi4_addr,
      axi4_strb      => axi4_strb,
      axi4_rw        => axi4_rw,
      axi4_rdy       => axi4_rdy,
      axi4_err       => axi4_err,
      axi4_word_size => axi4_word_size
      );

  -- Hookup AHB Bus Interface
  axi4lite_axi4_i : peripheral_dbg_pu_riscv_axi4_axi4
    generic map (
      ADDR_WIDTH => ADDR_WIDTH,
      DATA_WIDTH => DATA_WIDTH
      )
    port map (
      -- Debug interface signals
      axi4_clk       => axi4_clk,
      axi4_rst       => axi4_rst,
      axi4_di        => axi4_di,
      axi4_do        => axi4_do,
      axi4_addr      => axi4_addr,
      axi4_strb      => axi4_strb,
      axi4_rw        => axi4_rw,
      axi4_rdy       => axi4_rdy,
      axi4_err       => axi4_err,
      axi4_word_size => axi4_word_size,

      -- AHB Master signals
      HCLK      => HCLK,
      HRESETn   => HRESETn,
      HSEL      => HSEL,
      HADDR     => HADDR,
      HWDATA    => HWDATA,
      HRDATA    => HRDATA,
      HWRITE    => HWRITE,
      HSIZE     => HSIZE,
      HBURST    => HBURST,
      HPROT     => HPROT,
      HTRANS    => HTRANS,
      HMASTLOCK => HMASTLOCK,
      HREADY    => HREADY,
      HRESP     => HRESP
      );
end rtl;
