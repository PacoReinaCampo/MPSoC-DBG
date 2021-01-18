-- Converted from rtl/verilog/core/mpsoc_dbg_or1k_biu.sv
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
-- *   Nathan Yawn <nathan.yawn@opencores.org>
-- *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
-- */

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_or1k_biu is
  generic (
    X              : integer := 2;
    Y              : integer := 2;
    Z              : integer := 2;
    CORES_PER_TILE : integer := 1;
    CPU_ADDR_WIDTH : integer := 32;
    CPU_DATA_WIDTH : integer := 32
    );
  port (
    -- Debug interface signals
    tck_i        : in  std_logic;
    tlr_i        : in  std_logic;
    cpu_select_i : in  std_logic_vector(3 downto 0);
    data_i       : in  std_logic_vector(CPU_ADDR_WIDTH-1 downto 0);  -- Assume short words are in UPPER order bits!
    data_o       : out std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
    addr_i       : in  std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
    strobe_i     : in  std_logic;
    rd_wrn_i     : in  std_logic;
    rdy_o        : out std_logic;

    -- OR1K SPR bus signals
    cpu_clk_i  : in  std_logic;
    cpu_rstn_i : in  std_logic;
    cpu_addr_o : out xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_ADDR_WIDTH-1 downto 0);
    cpu_data_i : in  xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
    cpu_data_o : out xyz_std_logic_matrix(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)(CPU_DATA_WIDTH-1 downto 0);
    cpu_stb_o  : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    cpu_we_o   : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
    cpu_ack_i  : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)
    );
end mpsoc_dbg_or1k_biu;

architecture RTL of mpsoc_dbg_or1k_biu is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant STATE_IDLE     : std_logic := '0';
  constant STATE_TRANSFER : std_logic := '1';

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal cpu_data_int : std_logic_vector(CPU_DATA_WIDTH-1 downto 0);
  signal cpu_ack_int  : std_logic;
  signal cpu_stb_int  : std_logic;

  -- Registers
  signal addr_reg     : std_logic_vector(CPU_ADDR_WIDTH-1 downto 0);
  signal data_in_reg  : std_logic_vector(CPU_DATA_WIDTH-1 downto 0);  -- dbg->WB
  signal data_out_reg : std_logic_vector(CPU_DATA_WIDTH-1 downto 0);  -- WB->dbg
  signal wr_reg       : std_logic;
  signal str_sync     : std_logic;  -- This is 'active-toggle' rather than -high or -low.
  signal rdy_sync     : std_logic;      -- ditto, active-toggle

  -- Sync registers.  TFF indicates TCK domain, WBFF indicates cpu_clk domain
  signal rdy_sync_tff1   : std_logic;
  signal rdy_sync_tff2   : std_logic;
  signal rdy_sync_tff2q  : std_logic;   -- used to detect toggles
  signal str_sync_wbff1  : std_logic;
  signal str_sync_wbff2  : std_logic;
  signal str_sync_wbff2q : std_logic;   -- used to detect toggles

  -- Control Signals
  signal data_o_en   : std_logic;       -- latch wb_data_i
  signal rdy_sync_en : std_logic;  -- toggle the rdy_sync signal, indicate ready to TCK domain

  -- Internal signals
  signal start_toggle : std_logic;  -- CPU domain, indicates a toggle on the start strobe

  signal valid_selection : std_logic;  --set to 1 if value in input selection signal is < X*Y*Z*CORES_PER_TILE

  signal cpu_fsm_state  : std_logic;
  signal next_fsm_state : std_logic;

  signal rdy_sgn : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  valid_selection <= '1'
                     when (unsigned(cpu_select_i) < to_unsigned(X*Y*Z*CORES_PER_TILE, 4)) else '0';

  --////////////////////////////////////////////////////
  -- TCK clock domain
  -- There is no FSM here, just signal latching and clock
  -- domain synchronization

  -- Latch input data on 'start' strobe, if ready.
  processing_0 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      addr_reg    <= X"0";
      data_in_reg <= X"0";
      wr_reg      <= '0';
    elsif (rising_edge(tck_i)) then
      if (strobe_i = '1' and rdy_sgn = '1') then
        addr_reg <= addr_i;
        if (rd_wrn_i = '0') then
          data_in_reg <= data_i;
        end if;
        wr_reg <= not rd_wrn_i;
      end if;
    end if;
  end process;

  -- Create toggle-active strobe signal for clock sync.  This will start a transaction
  -- to the CPU once the toggle propagates to the FSM in the cpu_clk domain.
  processing_1 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      str_sync <= '0';
    elsif (rising_edge(tck_i)) then
      if (strobe_i = '1' and rdy_sgn = '1') then
        str_sync <= not str_sync;
      end if;
    end if;
  end process;

  -- Create rdy_o output.  Set on reset, clear on strobe (if set), set on input toggle
  processing_2 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      rdy_sync_tff1  <= '0';
      rdy_sync_tff2  <= '0';
      rdy_sync_tff2q <= '0';
      rdy_sgn        <= '1';
    elsif (rising_edge(tck_i)) then
      rdy_sync_tff1  <= rdy_sync;  -- Synchronize the ready signal across clock domains
      rdy_sync_tff2  <= rdy_sync_tff1;
      rdy_sync_tff2q <= rdy_sync_tff2;  -- used to detect toggles
      if (strobe_i = '1' and rdy_sgn = '1') then
        rdy_sgn <= '0';
      elsif (rdy_sync_tff2 /= rdy_sync_tff2q) then
        rdy_sgn <= '1';
      end if;
    end if;
  end process;

  rdy_o <= rdy_sgn;

  -- Direct assignments, unsynchronized

  data_o <= data_out_reg;

  generating_0 : for i in 0 to X - 1 generate
    generating_1 : for j in 0 to Y - 1 generate
      generating_2 : for k in 0 to Z - 1 generate
        generating_3 : for t in 0 to CORES_PER_TILE - 1 generate
          processing_3 : process (cpu_select_i)
          begin
            if (unsigned(cpu_select_i) = to_unsigned(i*j*k*t, 4)) then
              cpu_data_o(i, j, k)(t) <= data_in_reg;
              cpu_we_o(i, j, k)(t)   <= wr_reg;
              cpu_addr_o(i, j, k)(t) <= addr_reg;
              cpu_stb_o(i, j, k)(t)  <= cpu_stb_int;
            else
              cpu_data_o(i, j, k)(t) <= (others => '0');
              cpu_we_o(i, j, k)(t)   <= '0';
              cpu_addr_o(i, j, k)(t) <= (others => '0');
              cpu_stb_o(i, j, k)(t)  <= '0';
            end if;
          end process;
        end generate;
      end generate;
    end generate;
  end generate;

  generating_4 : for i in 0 to X - 1 generate
    generating_5 : for j in 0 to Y - 1 generate
      generating_6 : for k in 0 to Z - 1 generate
        generating_7 : for t in 0 to CORES_PER_TILE - 1 generate
          processing_4 : process (cpu_select_i)
          begin
            cpu_data_int <= (others => '0');
            cpu_ack_int  <= '0';
            if (unsigned(cpu_select_i) = to_unsigned(i*j*k*t, 4)) then
              cpu_data_int <= cpu_data_i(i, j, k)(t);
              cpu_ack_int  <= cpu_ack_i(i, j, k)(t);
            end if;
          end process;
        end generate;
      end generate;
    end generate;
  end generate;

  -- CPU clock domain

  -- synchronize the start strobe
  processing_5 : process (cpu_clk_i, cpu_rstn_i)
  begin
    if (cpu_rstn_i = '0') then
      str_sync_wbff1  <= '0';
      str_sync_wbff2  <= '0';
      str_sync_wbff2q <= '0';
    elsif (rising_edge(cpu_clk_i)) then
      str_sync_wbff1  <= str_sync;
      str_sync_wbff2  <= str_sync_wbff1;
      str_sync_wbff2q <= str_sync_wbff2;  -- used to detect toggles
    end if;
  end process;

  start_toggle <= to_stdlogic(str_sync_wbff2 /= str_sync_wbff2q);

  -- CPU->dbg data register
  processing_6 : process (cpu_clk_i, cpu_rstn_i)
  begin
    if (cpu_rstn_i = '0') then
      data_out_reg <= X"0";
    elsif (rising_edge(cpu_clk_i)) then
      if (data_o_en = '1') then
        data_out_reg <= cpu_data_int;
      end if;
    end if;
  end process;

  -- Create a toggle-active ready signal to send to the TCK domain
  processing_7 : process (cpu_clk_i, cpu_rstn_i)
  begin
    if (cpu_rstn_i = '0') then
      rdy_sync <= '0';
    elsif (rising_edge(cpu_clk_i)) then
      if (rdy_sync_en = '1') then
        rdy_sync <= not rdy_sync;
      end if;
    end if;
  end process;

  -- Small state machine to create OR1K SPR bus accesses
  -- Not much more that an 'in_progress' bit, but easier
  -- to read.  Deals with single-cycle and multi-cycle
  -- accesses.

  -- Sequential bit
  processing_8 : process (cpu_clk_i, cpu_rstn_i)
  begin
    if (cpu_rstn_i = '0') then
      cpu_fsm_state <= STATE_IDLE;
    elsif (rising_edge(cpu_clk_i)) then
      cpu_fsm_state <= next_fsm_state;
    end if;
  end process;

  -- Determination of next state (combinatorial)
  processing_9 : process (cpu_fsm_state, start_toggle, cpu_ack_int)
  begin
    case ((cpu_fsm_state)) is
      when STATE_IDLE =>
        if (start_toggle = '1' and cpu_ack_int = '0') then
          next_fsm_state <= STATE_TRANSFER;  -- Don't go to next state for 1-cycle transfer
        else
          next_fsm_state <= STATE_IDLE;
        end if;
      when STATE_TRANSFER =>
        if (cpu_ack_int = '1') then
          next_fsm_state <= STATE_IDLE;
        else
          next_fsm_state <= STATE_TRANSFER;
        end if;
      when others =>
        null;
    end case;
  end process;

  -- Outputs of state machine (combinatorial)
  processing_10 : process (cpu_fsm_state, start_toggle, cpu_ack_int, wr_reg)
  begin
    rdy_sync_en <= '0';
    data_o_en   <= '0';
    cpu_stb_int <= '0';
    case ((cpu_fsm_state)) is
      when STATE_IDLE =>
        if (start_toggle = '1') then
          cpu_stb_int <= '1';
          if (cpu_ack_int = '1') then
            rdy_sync_en <= '1';
          elsif (cpu_ack_int = '1' and wr_reg = '0') then  -- latch read data
            data_o_en <= '1';
          end if;
        end if;
      when STATE_TRANSFER =>
        -- OR1K behavioral model needs this.  OR1200 should be indifferent.
        cpu_stb_int <= '1';
        if (cpu_ack_int = '1') then
          data_o_en   <= '1';
          rdy_sync_en <= '1';
        end if;
      when others =>
        null;
    end case;
  end process;
end RTL;
