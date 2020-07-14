-- Converted from rtl/verilog/modules/common/riscv_osd_ctm.sv
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

entity riscv_osd_ctm is
  generic (
    XLEN : integer := 64;
    PLEN : integer := 64;

    MAX_REG_SIZE : integer := 64;

    ADDR_WIDTH : integer := 64;
    DATA_WIDTH : integer := 64
  );
  port (
    clk : in std_logic;
    rst : in std_logic;

    id : in std_logic_vector(XLEN-1 downto 0);

    debug_in_data  : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    debug_in_last  : in  std_logic;
    debug_in_valid : in  std_logic;
    debug_in_ready : out std_logic;

    debug_out_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
    debug_out_last  : out std_logic;
    debug_out_valid : out std_logic;
    debug_out_ready : in  std_logic;

    trace_valid    : in std_logic;
    trace_pc       : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    trace_npc      : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    trace_jal      : in std_logic;
    trace_jalr     : in std_logic;
    trace_branch   : in std_logic;
    trace_load     : in std_logic;
    trace_store    : in std_logic;
    trace_trap     : in std_logic;
    trace_xcpt     : in std_logic;
    trace_mem      : in std_logic;
    trace_csr      : in std_logic;
    trace_br_taken : in std_logic;
    trace_prv      : in std_logic_vector(1 downto 0);
    trace_addr     : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    trace_rdata    : in std_logic_vector(DATA_WIDTH-1 downto 0);
    trace_wdata    : in std_logic_vector(DATA_WIDTH-1 downto 0);
    trace_time     : in std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end riscv_osd_ctm;

architecture RTL of riscv_osd_ctm is
  component riscv_osd_regaccess_layer
    generic (
      XLEN : integer := 64;
      PLEN : integer := 64;

      MAX_REG_SIZE : integer := 64
    );
    port (
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

      module_in_data  : in  std_logic_vector(XLEN-1 downto 0);
      module_in_last  : in  std_logic;
      module_in_valid : in  std_logic;
      module_in_ready : out std_logic;

      module_out_data  : out std_logic_vector(XLEN-1 downto 0);
      module_out_last  : out std_logic;
      module_out_valid : out std_logic;
      module_out_ready : in  std_logic;

      reg_request : out std_logic;
      reg_write   : out std_logic;
      reg_addr    : out std_logic_vector(PLEN-1 downto 0);
      reg_size    : out std_logic_vector(1 downto 0);
      reg_wdata   : out std_logic_vector(MAX_REG_SIZE-1 downto 0);
      reg_ack     : in  std_logic;
      reg_err     : in  std_logic;
      reg_rdata   : in  std_logic_vector(MAX_REG_SIZE-1 downto 0);

      event_dest : out std_logic_vector(XLEN-1 downto 0);  -- DI address of the event destination
      stall      : out std_logic
    );
  end component;

  component riscv_osd_tracesample
    generic (
      WIDTH : integer := 64
    );
    port (
      clk          : in std_logic;
      rst          : in std_logic;
      sample_data  : in std_logic_vector(WIDTH-1 downto 0);
      sample_valid : in std_logic;

      fifo_data     : out std_logic_vector(WIDTH-1 downto 0);
      fifo_overflow : out std_logic;
      fifo_valid    : out std_logic;
      fifo_ready    : in  std_logic
    );
  end component;

  component riscv_osd_fifo
    generic (
      WIDTH : integer := 64;
      DEPTH : integer := 8
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      in_data  : in  std_logic_vector(WIDTH-1 downto 0);
      in_valid : in  std_logic;
      in_ready : out std_logic;

      out_data  : out std_logic_vector(WIDTH-1 downto 0);
      out_valid : out std_logic;
      out_ready : in  std_logic
    );
  end component;

  component riscv_osd_event_packetization_fixedwidth
    generic (
      XLEN       : integer := 64;
      DATA_WIDTH : integer := 64
    );
    port (
      clk : in std_logic;
      rst : in std_logic;

      debug_out_data  : out std_logic_vector(XLEN-1 downto 0);
      debug_out_last  : out std_logic;
      debug_out_valid : out std_logic;
      debug_out_ready : in  std_logic;

      -- DI address of this module (SRC)
      id : in std_logic_vector(XLEN-1 downto 0);

      -- DI address of the event destination (DEST)
      dest     : in std_logic_vector(XLEN-1 downto 0);
      -- Generate an overflow packet
      overflow : in std_logic;

      -- a new event is available
      event_available : in  std_logic;
      -- the packet has been sent
      event_consumed  : out std_logic;

      data : in std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant EW : integer := 3+XLEN+2+ADDR_WIDTH+ADDR_WIDTH;

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal reg_request : std_logic;
  signal reg_write   : std_logic;
  signal reg_addr    : std_logic_vector(63 downto 0);
  signal reg_size    : std_logic_vector(1 downto 0);
  signal reg_wdata   : std_logic_vector(XLEN-1 downto 0);
  signal reg_ack     : std_logic;
  signal reg_err     : std_logic;
  signal reg_rdata   : std_logic_vector(XLEN-1 downto 0);

  signal stall      : std_logic;
  signal event_dest : std_logic_vector(XLEN-1 downto 0);

  signal dp_in_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal dp_in_last  : std_logic;
  signal dp_in_valid : std_logic;
  signal dp_in_ready : std_logic;

  signal dp_out_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal dp_out_last  : std_logic;
  signal dp_out_valid : std_logic;
  signal dp_out_ready : std_logic;

  signal prv_reg : std_logic_vector(1 downto 0);

  signal sample_data     : std_logic_vector(EW-1 downto 0);
  signal sample_valid    : std_logic;
  signal timestamp       : std_logic_vector(XLEN-1 downto 0);
  signal fifo_data       : std_logic_vector(EW-1 downto 0);
  signal fifo_overflow   : std_logic;
  signal fifo_valid      : std_logic;
  signal fifo_ready      : std_logic;
  signal packet_data     : std_logic_vector(EW-1 downto 0);
  signal packet_overflow : std_logic;
  signal packet_valid    : std_logic;
  signal packet_ready    : std_logic;

  signal sample_prvchange : std_logic;

  signal tracesample_sample_valid : std_logic;

  signal fifo_in_data  : std_logic_vector(EW downto 0);
  signal fifo_out_data : std_logic_vector(EW downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --
  osd_regaccess_layer : riscv_osd_regaccess_layer
    generic map (
      XLEN => XLEN,
      PLEN => PLEN,

      MAX_REG_SIZE => MAX_REG_SIZE
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

      module_in_data  => dp_out_data,
      module_in_last  => dp_out_last,
      module_in_valid => dp_out_valid,
      module_in_ready => dp_out_ready,

      module_out_data  => dp_in_data,
      module_out_last  => dp_in_last,
      module_out_valid => dp_in_valid,
      module_out_ready => dp_in_ready,

      reg_request => reg_request,
      reg_write   => reg_write,
      reg_addr    => reg_addr,
      reg_size    => reg_size,
      reg_wdata   => reg_wdata,
      reg_ack     => reg_ack,
      reg_err     => reg_err,
      reg_rdata   => reg_rdata,

      event_dest => event_dest,
      stall      => stall
    );

  -- this module cannot receive data except for configuration packets
  dp_in_ready <= '0';

  processing_0 : process (reg_addr, reg_request)
  begin
    reg_ack   <= '1';
    reg_rdata <= (others => 'X');
    reg_err   <= '0';

    case (reg_addr) is
      when X"0000000000000200" =>
        reg_rdata <= std_logic_vector(to_unsigned(ADDR_WIDTH, XLEN));
      when X"0000000000000201" =>
        reg_rdata <= std_logic_vector(to_unsigned(DATA_WIDTH, XLEN));
      when others =>
        reg_err <= reg_request;
    end case;
  end process;

  processing_1 : process (clk)
  begin
    if (rising_edge(clk)) then
      prv_reg <= trace_prv;
    end if;
  end process;

  sample_prvchange <= to_stdlogic(prv_reg /= trace_prv);
  sample_valid     <= (trace_valid and not trace_mem and (trace_jal or trace_jalr)) or sample_prvchange;
  sample_data      <= sample_prvchange & trace_jal & trace_jalr & trace_prv & trace_pc & trace_npc & timestamp;

  processing_2 : process (clk)
  begin
    if (rising_edge(clk)) then
      if (rst = '1') then
        timestamp <= (others => '0');
      else
        timestamp <= std_logic_vector(unsigned(timestamp)+to_unsigned(1, XLEN));
      end if;
    end if;
  end process;

  osd_tracesample : riscv_osd_tracesample
    generic map (
      WIDTH => EW
    )
    port map (
      clk          => clk,
      rst          => rst,
      sample_data  => sample_data,
      sample_valid => tracesample_sample_valid,

      fifo_data     => fifo_data,
      fifo_overflow => fifo_overflow,
      fifo_valid    => fifo_valid,
      fifo_ready    => fifo_ready
    );

  tracesample_sample_valid <= sample_valid and not stall;

  osd_fifo : riscv_osd_fifo
    generic map (
      WIDTH => EW+1,
      DEPTH => 8
    )
    port map (
      clk => clk,
      rst => rst,

      in_data  => fifo_in_data,
      in_valid => fifo_valid,
      in_ready => fifo_ready,

      out_data  => fifo_out_data,
      out_valid => packet_valid,
      out_ready => packet_ready
    );

  fifo_in_data  <= (fifo_overflow & fifo_data(EW-1 downto 0));

  packet_overflow <= fifo_out_data(EW);
  packet_data     <= fifo_out_data(EW-1 downto 0);

  osd_event_packetization_fixedwidth : riscv_osd_event_packetization_fixedwidth
    generic map (
      XLEN => XLEN,

      DATA_WIDTH => EW
    )
    port map (
      clk => clk,
      rst => rst,

      debug_out_data  => dp_out_data,
      debug_out_last  => dp_out_last,
      debug_out_valid => dp_out_valid,
      debug_out_ready => dp_out_ready,

      id              => id,
      dest            => event_dest,
      overflow        => packet_overflow,
      event_available => packet_valid,
      event_consumed  => packet_ready,

      data => packet_data
    );
end RTL;
