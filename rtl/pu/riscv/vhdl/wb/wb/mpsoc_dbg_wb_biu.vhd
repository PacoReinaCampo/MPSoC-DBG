-- Converted from rtl/verilog/wb/mpsoc_dbg_wb_biu.sv
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

-- Top module
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_wb_biu is
  generic (
    LITTLE_ENDIAN : std_logic := '1';
    ADDR_WIDTH    : integer   := 32;
    DATA_WIDTH    : integer   := 32
    );
  port (
    -- Debug interface signals
    biu_clk       : in  std_logic;
    biu_rst       : in  std_logic;
    biu_di        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_do        : out std_logic_vector(DATA_WIDTH-1 downto 0);
    biu_addr      : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
    biu_strb      : in  std_logic;
    biu_rw        : in  std_logic;
    biu_rdy       : out std_logic;
    biu_err       : out std_logic;
    biu_word_size : in  std_logic_vector(3 downto 0);

    -- Wishbone signals
    wb_clk_i : in  std_logic;
    wb_cyc_o : out std_logic;
    wb_stb_o : out std_logic;
    wb_we_o  : out std_logic;
    wb_cti_o : out std_logic_vector(2 downto 0);
    wb_bte_o : out std_logic_vector(1 downto 0);
    wb_adr_o : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    wb_sel_o : out std_logic_vector(DATA_WIDTH/8-1 downto 0);
    wb_dat_o : out std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_dat_i : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    wb_ack_i : in  std_logic;
    wb_err_i : in  std_logic
    );
end mpsoc_dbg_wb_biu;

architecture RTL of mpsoc_dbg_wb_biu is
  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant IDLE     : std_logic := '1';
  constant TRANSFER : std_logic := '0';

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --
  signal sel_reg      : std_logic_vector(3 downto 0);
  signal addr_reg     : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal data_in_reg  : std_logic_vector(DATA_WIDTH-1 downto 0);  -- dbg->WB
  signal data_out_reg : std_logic_vector(DATA_WIDTH-1 downto 0);  -- WB->dbg
  signal wr_reg       : std_logic;
  signal str_sync     : std_logic;  -- This is 'active-toggle' rather than -high or -low.
  signal rdy_sync     : std_logic;      -- ditto, active-toggle
  signal err_reg      : std_logic;

  -- Sync registers.  TFF indicates TCK domain, WBFF indicates wb_clk domain
  signal wb_rst_sync     : std_logic_vector(1 downto 0);
  signal wb_rst          : std_logic;
  signal rdy_sync_tff1   : std_logic;
  signal rdy_sync_tff2   : std_logic;
  signal rdy_sync_tff2q  : std_logic;   -- used to detect toggles
  signal str_sync_wbff1  : std_logic;
  signal str_sync_wbff2  : std_logic;
  signal str_sync_wbff2q : std_logic;   -- used to detect toggles

  -- Control Signals
  signal wb_resp : std_logic;  -- WB response received (either ACK or ERR)

  -- Internal signals
  signal be_dec           : std_logic_vector(3 downto 0);  -- word_size and low-order address bits decoded to SEL bits
  signal start_toggle     : std_logic;  -- WB domain, indicates a toggle on the start strobe
  signal swapped_data_in  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal swapped_data_out : std_logic_vector(DATA_WIDTH-1 downto 0);

  --WB FSM
  signal wb_fsm_state : std_logic;

  signal biu_rdy_sgn : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  --////////////////////////////////////////////////////
  -- TCK clock domain
  --

  -- There is no FSM here, just signal latching and clock domain synchronization

  -- Create byte enable signals from word_size and address (combinatorial)
  processing_0 : process (biu_word_size)
    variable state_addr_a : std_logic_vector(1 downto 0);
    variable state_addr_b : std_logic;
  begin
    case (biu_word_size) is
      when X"1" =>
        case (state_addr_a) is
          when "00" =>
            if (LITTLE_ENDIAN = '1') then
              be_dec <= "0001";
            else 
              be_dec <= "1000";
            end if;
          when "01" =>
            if (LITTLE_ENDIAN = '1') then
              be_dec <= "0010";
            else 
              be_dec <= "0100";
            end if;
          when "10" =>
            if (LITTLE_ENDIAN = '1') then
              be_dec <= "0100";
            else 
              be_dec <= "0010";
            end if;
          when "11" =>
            if (LITTLE_ENDIAN = '1') then
              be_dec <= "1000";
            else 
              be_dec <= "0001";
            end if;
          when others =>
            null;
        end case;
      when X"2" =>
        case (state_addr_b) is
          when '0' =>
            if (LITTLE_ENDIAN = '1') then
              be_dec <= "0011";
            else 
              be_dec <= "1100";
            end if;
          when '1' =>
            if (LITTLE_ENDIAN = '1') then
              be_dec <= "1100";
            else 
              be_dec <= "0011";
            end if;
          when others =>
            null;
        end case;
      when others =>
        -- default to 32-bit access
        be_dec <= "1111";
    end case;
    state_addr_a := biu_addr(1 downto 0);
    state_addr_b := biu_addr(1);
  end process;

  -- Byte- or word-swap data as necessary.  Use the non-latched be_dec signal,
  -- since it and the swapped data will be latched at the same time.
  -- Remember that since the data is shifted in LSB-first, shorter words
  -- will be in the high-order bits. (combinatorial)
  processing_1 : process (be_dec)
  begin
    case (be_dec) is
      when "1111" =>
        swapped_data_in <= biu_di;
      when "0011" =>
        swapped_data_in <= (X"0" & biu_di(31 downto 16));
      when "1100" =>
        swapped_data_in <= biu_di;
      when "0001" =>
        swapped_data_in <= (X"0" & biu_di(31 downto 24));
      when "0010" =>
        swapped_data_in <= (X"0" & biu_di(31 downto 24) & X"0");
      when "0100" =>
        swapped_data_in <= (X"0" & biu_di(31 downto 24) & X"0");
      when "1000" =>
        swapped_data_in <= (biu_di(31 downto 24) & X"0");
      when others =>
        -- Shouldn't be possible
        swapped_data_in <= biu_di;
    end case;
  end process;

  -- Latch input data on 'start' strobe, if ready.
  processing_2 : process (biu_clk, biu_rst)
  begin
    if (biu_rst = '1') then
      sel_reg     <= X"0";
      addr_reg    <= X"0";
      data_in_reg <= X"0";
      wr_reg      <= '0';
    elsif (rising_edge(biu_clk)) then
      if (biu_strb = '1' and biu_rdy_sgn = '1') then
        sel_reg  <= be_dec;
        addr_reg <= biu_addr;
        wr_reg   <= not biu_rw;
        if (biu_rw = '0') then
          data_in_reg <= swapped_data_in;
        end if;
      end if;
    end if;
  end process;

  -- Create toggle-active strobe signal for clock sync.  This will start a transaction
  -- on the WB once the toggle propagates to the FSM in the WB domain.
  processing_3 : process (biu_clk, biu_rst)
  begin
    if (biu_rst = '1') then
      str_sync <= '0';
    elsif (rising_edge(biu_clk)) then
      if (biu_strb = '1' and biu_rdy_sgn = '1') then
        str_sync <= not str_sync;
      end if;
    end if;
  end process;

  -- Create biu_rdy output.  Set on reset, clear on strobe (if set), set on input toggle
  processing_4 : process (biu_clk, biu_rst)
  begin
    if (biu_rst = '1') then
      rdy_sync_tff1  <= '0';
      rdy_sync_tff2  <= '0';
      rdy_sync_tff2q <= '0';
      biu_rdy_sgn    <= '1';
    elsif (rising_edge(biu_clk)) then
      rdy_sync_tff1  <= rdy_sync;  -- Synchronize the ready signal across clock domains
      rdy_sync_tff2  <= rdy_sync_tff1;
      rdy_sync_tff2q <= rdy_sync_tff2;  -- used to detect toggles

      if (biu_strb = '1' and biu_rdy_sgn = '1') then
        biu_rdy_sgn <= '0';
      elsif (rdy_sync_tff2 /= rdy_sync_tff2q) then
        biu_rdy_sgn <= '1';
      end if;
    end if;
  end process;

  biu_rdy <= biu_rdy_sgn;

  -- Direct assignments, unsynchronized
  wb_dat_o <= data_in_reg;
  wb_we_o  <= wr_reg;
  wb_adr_o <= addr_reg;
  wb_sel_o <= sel_reg;

  biu_do  <= data_out_reg;
  biu_err <= err_reg;

  wb_cti_o <= (others => '0');
  wb_bte_o <= (others => '0');

  --/////////////////////////////////////////////////////
  -- Wishbone clock domain
  --

  -- synchronize asynchronous active high reset
  processing_5 : process (wb_clk_i, biu_rst)
  begin
    if (biu_rst = '1') then
      wb_rst_sync <= "11";
    elsif (rising_edge(wb_clk_i)) then
      wb_rst_sync <= "01";
    end if;
  end process;

  wb_rst <= wb_rst_sync(0);

  -- synchronize the start strobe
  processing_6 : process (wb_clk_i, wb_rst)
  begin
    if (wb_rst = '1') then
      str_sync_wbff1  <= '0';
      str_sync_wbff2  <= '0';
      str_sync_wbff2q <= '0';
    elsif (rising_edge(wb_clk_i)) then
      str_sync_wbff1  <= str_sync;
      str_sync_wbff2  <= str_sync_wbff1;
      str_sync_wbff2q <= str_sync_wbff2;  -- used to detect toggles
    end if;
  end process;

  start_toggle <= to_stdlogic(str_sync_wbff2 /= str_sync_wbff2q);

  -- Error indicator register
  processing_7 : process (wb_clk_i, wb_rst)
  begin
    if (wb_rst = '1') then
      err_reg <= '0';
    elsif (rising_edge(wb_clk_i)) then
      if (wb_resp = '1') then
        err_reg <= wb_err_i;
      end if;
    end if;
  end process;

  -- Byte- or word-swap the WB->dbg data, as necessary (combinatorial)
  -- We assume bits not required by SEL are don't care.  We reuse assignments
  -- where possible to keep the MUX smaller.  (combinatorial)
  processing_8 : process (sel_reg)
  begin
    case (sel_reg) is
      when "1111" =>
        swapped_data_out <= wb_dat_i;
      when "0011" =>
        swapped_data_out <= wb_dat_i;
      when "1100" =>
        swapped_data_out <= (X"0" & wb_dat_i(31 downto 16));
      when "0001" =>
        swapped_data_out <= wb_dat_i;
      when "0010" =>
        swapped_data_out <= (X"0" & wb_dat_i(15 downto 8));
      when "0100" =>
        swapped_data_out <= (X"0" & wb_dat_i(31 downto 16));
      when "1000" =>
        swapped_data_out <= (X"0" & wb_dat_i(31 downto 24));
      when others =>
        -- Shouldn't be possible
        swapped_data_out <= wb_dat_i;
    end case;
  end process;

  -- WB->dbg data register
  processing_9 : process (wb_clk_i, wb_rst)
  begin
    if (wb_rst = '1') then
      data_out_reg <= X"0";
    elsif (rising_edge(wb_clk_i)) then
      if (wb_resp = '1') then
        data_out_reg <= swapped_data_out;
      end if;
    end if;
  end process;

  -- Create a toggle-active ready signal to send to the TCK domain
  processing_10 : process (wb_clk_i, wb_rst)
  begin
    if (wb_rst = '1') then
      rdy_sync <= '0';
    elsif (rising_edge(wb_clk_i)) then
      if (wb_resp = '1') then
        rdy_sync <= not rdy_sync;
      end if;
    end if;
  end process;

  -- Small state machine to create WB accesses
  -- Not much more that an 'in_progress' bit, but easier to read
  -- Handles single-cycle and multi-cycle accesses.

  wb_resp <= wb_ack_i or wb_err_i;

  processing_11 : process (wb_clk_i, wb_rst)
  begin
    if (wb_rst = '1') then
      wb_cyc_o     <= '0';
      wb_stb_o     <= '0';
      wb_fsm_state <= IDLE;
    elsif (rising_edge(wb_clk_i)) then
      case ((wb_fsm_state)) is
        when IDLE =>
          if (start_toggle = '1') then
            wb_cyc_o     <= '1';
            wb_stb_o     <= '1';
            wb_fsm_state <= TRANSFER;
          end if;
        when TRANSFER =>
          if (wb_resp = '1') then
            wb_cyc_o     <= '0';
            wb_stb_o     <= '0';
            wb_fsm_state <= IDLE;
          end if;
        when others =>
          null;
      end case;
    end if;
  end process;
end RTL;
