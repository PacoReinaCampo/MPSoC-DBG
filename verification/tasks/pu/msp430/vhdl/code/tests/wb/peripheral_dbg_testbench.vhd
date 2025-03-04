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
--              MSP430 CPU                                                    --  
--              Processing Unit                                               --  
--                                                                            --  
--------------------------------------------------------------------------------

-- Copyright (c) 2015-2016 by the author(s)
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
--   Olivier Girard <olgirard@gmail.com>
--   Paco Reina Campo <pacoreinacampo@queenfield.tech>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.peripheral_dbg_pu_msp430_pkg.all;

entity peripheral_dbg_testbench is
  port (
    dbg_cpu_reset   : out std_logic;
    dbg_freeze      : out std_logic;
    dbg_halt_cmd    : out std_logic;
    dbg_i2c_sda_out : out std_logic;
    dbg_mem_en      : out std_logic;
    dbg_reg_wr      : out std_logic;
    dbg_uart_txd    : out std_logic;
    dbg_mem_wr      : out std_logic_vector (1 downto 0);
    dbg_mem_addr    : out std_logic_vector (15 downto 0);
    dbg_mem_dout    : out std_logic_vector (15 downto 0);

    cpu_en_s          : in std_logic;
    dbg_clk           : in std_logic;
    dbg_en_s          : in std_logic;
    dbg_halt_st       : in std_logic;
    dbg_i2c_scl       : in std_logic;
    dbg_i2c_sda_in    : in std_logic;
    dbg_rst           : in std_logic;
    dbg_uart_rxd      : in std_logic;
    decode_noirq      : in std_logic;
    eu_mb_en          : in std_logic;
    puc_pnd_set       : in std_logic;
    eu_mb_wr          : in std_logic_vector (1 downto 0);
    dbg_i2c_addr      : in std_logic_vector (6 downto 0);
    dbg_i2c_broadcast : in std_logic_vector (6 downto 0);
    cpu_nr_inst       : in std_logic_vector (7 downto 0);
    cpu_nr_total      : in std_logic_vector (7 downto 0);
    dbg_mem_din       : in std_logic_vector (15 downto 0);
    dbg_reg_din       : in std_logic_vector (15 downto 0);
    eu_mab            : in std_logic_vector (15 downto 0);
    fe_mdb_in         : in std_logic_vector (15 downto 0);
    pc                : in std_logic_vector (15 downto 0);
    cpu_id            : in std_logic_vector (31 downto 0)
  );
end peripheral_dbg_testbench;

architecture rtl of peripheral_dbg_testbench is

  ------------------------------------------------------------------------------
  -- Components
  ------------------------------------------------------------------------------

  component peripheral_dbg_pu_msp430
    port (
      dbg_cpu_reset   : out std_logic;
      dbg_freeze      : out std_logic;
      dbg_halt_cmd    : out std_logic;
      dbg_i2c_sda_out : out std_logic;
      dbg_mem_en      : out std_logic;
      dbg_reg_wr      : out std_logic;
      dbg_uart_txd    : out std_logic;
      dbg_mem_wr      : out std_logic_vector (1 downto 0);
      dbg_mem_addr    : out std_logic_vector (15 downto 0);
      dbg_mem_dout    : out std_logic_vector (15 downto 0);

      cpu_en_s          : in std_logic;
      dbg_clk           : in std_logic;
      dbg_en_s          : in std_logic;
      dbg_halt_st       : in std_logic;
      dbg_i2c_scl       : in std_logic;
      dbg_i2c_sda_in    : in std_logic;
      dbg_rst           : in std_logic;
      dbg_uart_rxd      : in std_logic;
      decode_noirq      : in std_logic;
      eu_mb_en          : in std_logic;
      puc_pnd_set       : in std_logic;
      eu_mb_wr          : in std_logic_vector (1 downto 0);
      dbg_i2c_addr      : in std_logic_vector (6 downto 0);
      dbg_i2c_broadcast : in std_logic_vector (6 downto 0);
      cpu_nr_inst       : in std_logic_vector (7 downto 0);
      cpu_nr_total      : in std_logic_vector (7 downto 0);
      dbg_mem_din       : in std_logic_vector (15 downto 0);
      dbg_reg_din       : in std_logic_vector (15 downto 0);
      eu_mab            : in std_logic_vector (15 downto 0);
      fe_mdb_in         : in std_logic_vector (15 downto 0);
      pc                : in std_logic_vector (15 downto 0);
      cpu_id            : in std_logic_vector (31 downto 0)
    );
  end component peripheral_dbg_pu_msp430;

begin

  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  dbg_pu_msp430 : peripheral_dbg_pu_msp430
    port map (
      dbg_cpu_reset   => dbg_cpu_reset,
      dbg_freeze      => dbg_freeze,
      dbg_halt_cmd    => dbg_halt_cmd,
      dbg_i2c_sda_out => dbg_i2c_sda_out,
      dbg_mem_en      => dbg_mem_en,
      dbg_reg_wr      => dbg_reg_wr,
      dbg_uart_txd    => dbg_uart_txd,
      dbg_mem_wr      => dbg_mem_wr,
      dbg_mem_addr    => dbg_mem_addr,
      dbg_mem_dout    => dbg_mem_dout,

      cpu_en_s          => cpu_en_s,
      dbg_clk           => dbg_clk,
      dbg_en_s          => dbg_en_s,
      dbg_halt_st       => dbg_halt_st,
      dbg_i2c_scl       => dbg_i2c_scl,
      dbg_i2c_sda_in    => dbg_i2c_sda_in,
      dbg_rst           => dbg_rst,
      dbg_uart_rxd      => dbg_uart_rxd,
      decode_noirq      => decode_noirq,
      eu_mb_en          => eu_mb_en,
      puc_pnd_set       => puc_pnd_set,
      eu_mb_wr          => eu_mb_wr,
      dbg_i2c_addr      => dbg_i2c_addr,
      dbg_i2c_broadcast => dbg_i2c_broadcast,
      cpu_nr_inst       => cpu_nr_inst,
      cpu_nr_total      => cpu_nr_total,
      dbg_mem_din       => dbg_mem_din,
      dbg_reg_din       => dbg_reg_din,
      eu_mab            => eu_mab,
      fe_mdb_in         => fe_mdb_in,
      pc                => pc,
      cpu_id            => cpu_id
    );
end rtl;
