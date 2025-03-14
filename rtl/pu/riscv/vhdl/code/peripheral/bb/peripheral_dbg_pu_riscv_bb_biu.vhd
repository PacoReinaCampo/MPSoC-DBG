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

entity peripheral_dbg_pu_riscv_bb_biu is
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
end peripheral_dbg_pu_riscv_bb_biu;

architecture rtl of peripheral_dbg_pu_riscv_bb_biu is
  ------------------------------------------------------------------------------
  -- Constants
  ------------------------------------------------------------------------------
  constant IDLE    : std_logic_vector(1 downto 0) := "10";
  constant ADDRESS : std_logic_vector(1 downto 0) := "01";
  constant DATA    : std_logic_vector(1 downto 0) := "00";

  ------------------------------------------------------------------------------
  -- Variables
  ------------------------------------------------------------------------------
  signal data_out_reg : std_logic_vector(DATA_WIDTH-1 downto 0);  -- AHB->dbg
  signal str_sync     : std_logic;  -- This is 'active-toggle' rather than -high or -low.
  signal rdy_sync     : std_logic;      -- ditto, active-toggle

  -- Sync registers.  TFF indicates TCK domain, AFF indicates AHB domain
  signal ahb_rstn_sync  : std_logic_vector(1 downto 0);
  signal ahb_rstn       : std_logic;
  signal rdy_sync_tff1  : std_logic;
  signal rdy_sync_tff2  : std_logic;
  signal rdy_sync_tff2q : std_logic;    -- used to detect toggles
  signal str_sync_aff1  : std_logic;
  signal str_sync_aff2  : std_logic;
  signal str_sync_aff2q : std_logic;    -- used to detect toggles

  -- Internal signals
  signal start_toggle      : std_logic;  -- AHB domain, indicates a toggle on the start strobe
  signal start_toggle_hold : std_logic;  -- hold start_toggle if AHB bus busy (not-ready)
  signal ahb_transfer_ack  : std_logic;  -- AHB bus responded to data transfer

  -- AHB FSM
  signal ahb_fsm_state : std_logic_vector(1 downto 0);

  signal biu_rdy_sgn : std_logic;

  signal HADDR_SGN : std_logic_vector(ADDR_WIDTH-1 downto 0);

begin
  ------------------------------------------------------------------------------
  -- Module Body
  ------------------------------------------------------------------------------

  -- TCK clock domain

  -- There is no FSM here, just signal latching and clock domain synchronization

  -- Create byte enable signals from word_size and address
  processing_0 : process (biu_clk)
  begin
    if (rising_edge(biu_clk)) then
      if (biu_strb = '1' and biu_rdy_sgn = '1') then
        case ((biu_word_size)) is
          when X"1" =>
            HSIZE <= HSIZE_BYTE;
          when X"2" =>
            HSIZE <= HSIZE_HWORD;
          when X"4" =>
            HSIZE <= HSIZE_WORD;
          when others =>
            HSIZE <= HSIZE_DWORD;
        end case;
      end if;
    end if;
  end process;

  generating_0 : if (DATA_WIDTH = 32) generate
    processing_1 : process (biu_clk)
    begin
      if (rising_edge(biu_clk)) then
        if (biu_strb = '1' and biu_rdy_sgn = '1') then
          case ((biu_word_size)) is
            when X"1" =>
              HWDATA <= (biu_di(31 downto 31-8+1) & biu_di(31 downto 31-8+1) &
                         biu_di(31 downto 31-8+1) & biu_di(31 downto 31-8+1));
            when X"2" =>
              HWDATA <= (biu_di(31 downto 31-16+1) & biu_di(31 downto 31-16+1));
            when others =>
              HWDATA <= biu_di;
          end case;
        end if;
      end if;
    end process;
  elsif (DATA_WIDTH = 64) generate
    processing_2 : process (biu_clk)
    begin
      if (rising_edge(biu_clk)) then
        if (biu_strb = '1' and biu_rdy_sgn = '1') then
          case ((biu_word_size)) is
            when X"1" =>
              HWDATA <= (biu_di(63 downto 63-8+1) & biu_di(63 downto 63-8+1) &
                         biu_di(63 downto 63-8+1) & biu_di(63 downto 63-8+1) &
                         biu_di(63 downto 63-8+1) & biu_di(63 downto 63-8+1) &
                         biu_di(63 downto 63-8+1) & biu_di(63 downto 63-8+1));
            when X"2" =>
              HWDATA <= (biu_di(63 downto 63-16+1) & biu_di(63 downto 63-16+1) &
                         biu_di(63 downto 63-16+1) & biu_di(63 downto 63-16+1));
            when X"4" =>
              HWDATA <= (biu_di(63 downto 63-32+1) & biu_di(63 downto 63-32+1));
            when others =>
              HWDATA <= biu_di;
          end case;
        end if;
      end if;
    end process;
  end generate;

  -- Latch input data on 'start' strobe, if ready.
  processing_3 : process (biu_clk, biu_rst)
  begin
    if (biu_rst = '1') then
      HADDR_SGN <= X"0";
      HWRITE    <= '0';
    elsif (rising_edge(biu_clk)) then
      if (biu_strb = '1' and biu_rdy_sgn = '1') then
        HADDR_SGN <= biu_addr;
        HWRITE    <= not biu_rw;
      end if;
    end if;
  end process;

  HADDR <= HADDR_SGN;
  -- Create toggle-active strobe signal for clock sync.  This will start a transaction
  -- on the AHB once the toggle propagates to the FSM in the AHB domain.
  processing_4 : process (biu_clk, biu_rst)
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
  processing_5 : process (biu_clk, biu_rst)
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

  -- AHB clock domain

  -- synchronize asynchronous active high reset
  processing_6 : process (HCLK, biu_rst)
  begin
    if (biu_rst = '1') then
      ahb_rstn_sync <= (others => '0');
    elsif (rising_edge(HCLK)) then
      ahb_rstn_sync <= ('1' & ahb_rstn_sync(1));
    end if;
  end process;

  ahb_rstn <= not (not HRESETn or not ahb_rstn_sync(0));

  -- synchronize the start strobe
  processing_7 : process (HCLK, ahb_rstn)
  begin
    if (ahb_rstn = '0') then
      str_sync_aff1  <= '0';
      str_sync_aff2  <= '0';
      str_sync_aff2q <= '0';
    elsif (rising_edge(HCLK)) then
      str_sync_aff1  <= str_sync;
      str_sync_aff2  <= str_sync_aff1;
      str_sync_aff2q <= str_sync_aff2;  -- used to detect toggles
    end if;
  end process;

  start_toggle <= to_stdlogic(str_sync_aff2 /= str_sync_aff2q);

  processing_8 : process (HCLK, ahb_rstn)
  begin
    if (ahb_rstn = '0') then
      start_toggle_hold <= '0';
    elsif (rising_edge(HCLK)) then
      start_toggle_hold <= not ahb_transfer_ack and (start_toggle or start_toggle_hold);
    end if;
  end process;

  -- Bus Error register
  processing_9 : process (HCLK, ahb_rstn)
  begin
    if (ahb_rstn = '0') then
      biu_err <= '0';
    elsif (rising_edge(HCLK)) then
      if (ahb_transfer_ack = '1') then
        biu_err <= HRESP;
      end if;
    end if;
  end process;

  -- Received data register
  generating_1 : if (DATA_WIDTH = 32) generate
    processing_10 : process (HCLK)
      variable state_haddr_b : std_logic_vector(1 downto 0);
      variable state_haddr_d : std_logic;
    begin
      if (rising_edge(HCLK)) then
        if (ahb_transfer_ack = '1') then
          case ((biu_word_size)) is
            when X"1" =>
              case (state_haddr_b) is
                when "00" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000" & HRDATA(7 downto 7-8+1));
                  else
                    biu_do <= (X"000000" & HRDATA(31 downto 31-8+1));
                  end if;
                when "01" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000" & HRDATA(15 downto 15-8+1));
                  else
                    biu_do <= (X"000000" & HRDATA(23 downto 23-8+1));
                  end if;
                when "10" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000" & HRDATA(23 downto 23-8+1));
                  else
                    biu_do <= (X"000000" & HRDATA(15 downto 15-8+1));
                  end if;
                when "11" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000" & HRDATA(31 downto 31-8+1));
                  else
                    biu_do <= (X"000000" & HRDATA(7 downto 7-8+1));
                  end if;
                when others =>
                  null;
              end case;
            when X"2" =>
              case (state_haddr_d) is
                when '0' =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000" & HRDATA(15 downto 15-16+1));
                  else
                    biu_do <= (X"00000000" & HRDATA(31 downto 31-16+1));
                  end if;
                when '1' =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000" & HRDATA(31 downto 31-16+1));
                  else
                    biu_do <= (X"00000000" & HRDATA(15 downto 15-16+1));
                  end if;
                when others =>
                  null;
              end case;
            when others =>
              biu_do <= HRDATA;
          end case;
        end if;
      end if;

      state_haddr_b := HADDR_SGN(1 downto 0);
      state_haddr_d := HADDR_SGN(1);
    end process;
  elsif (DATA_WIDTH = 64) generate
    processing_11 : process (HCLK)
      variable state_haddr_a : std_logic_vector(2 downto 0);
      variable state_haddr_c : std_logic_vector(1 downto 0);
      variable state_haddr_e : std_logic;
    begin
      if (rising_edge(HCLK)) then
        if (ahb_transfer_ack = '1') then
          case ((biu_word_size)) is
            when X"1" =>
              case (state_haddr_a) is
                when "000" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(7 downto 7-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(63 downto 63-8+1));
                  end if;
                when "001" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(15 downto 15-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(55 downto 55-8+1));
                  end if;
                when "010" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(23 downto 23-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(47 downto 47-8+1));
                  end if;
                when "011" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(31 downto 31-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(39 downto 39-8+1));
                  end if;
                when "100" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(39 downto 39-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(31 downto 31-8+1));
                  end if;
                when "101" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(47 downto 47-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(23 downto 23-8+1));
                  end if;
                when "110" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(55 downto 55-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(15 downto 15-8+1));
                  end if;
                when "111" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000000000" & HRDATA(63 downto 63-8+1));
                  else
                    biu_do <= (X"00000000000000" & HRDATA(7 downto 7-8+1));
                  end if;
                when others =>
                  null;
              end case;
            when X"2" =>
              case (state_haddr_c) is
                when "00" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000000000" & HRDATA(15 downto 15-16+1));
                  else
                    biu_do <= (X"000000000000" & HRDATA(63 downto 63-16+1));
                  end if;
                when "01" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000000000" & HRDATA(31 downto 31-16+1));
                  else
                    biu_do <= (X"000000000000" & HRDATA(47 downto 47-16+1));
                  end if;
                when "10" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000000000" & HRDATA(47 downto 47-16+1));
                  else
                    biu_do <= (X"000000000000" & HRDATA(31 downto 31-16+1));
                  end if;
                when "11" =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"000000000000" & HRDATA(63 downto 63-16+1));
                  else
                    biu_do <= (X"000000000000" & HRDATA(15 downto 15-16+1));
                  end if;
                when others =>
                  null;
              end case;
            when X"4" =>
              case (state_haddr_e) is
                when '0' =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000" & HRDATA(31 downto 31-32+1));
                  else
                    biu_do <= (X"0000" & HRDATA(63 downto 63-32+1));
                  end if;
                when '1' =>
                  if (LITTLE_ENDIAN = '1') then
                    biu_do <= (X"00000000" & HRDATA(63 downto 63-32+1));
                  else
                    biu_do <= (X"0000" & HRDATA(31 downto 31-32+1));
                  end if;
                when others =>
                  null;
              end case;
            when others =>
              biu_do <= HRDATA;
          end case;
        end if;
      end if;

      state_haddr_a := HADDR_SGN(2 downto 0);
      state_haddr_c := HADDR_SGN(2 downto 1);
      state_haddr_e := HADDR_SGN(2);
    end process;
  end generate;

  -- Create a toggle-active ready signal to send to the TCK domain
  processing_12 : process (HCLK, ahb_rstn)
  begin
    if (ahb_rstn = '0') then
      rdy_sync <= '0';
    elsif (rising_edge(HCLK)) then
      if (ahb_transfer_ack = '1') then
        rdy_sync <= not rdy_sync;
      end if;
    end if;
  end process;

  -- State machine to create AHB accesses

  ahb_transfer_ack <= HREADY and to_stdlogic(ahb_fsm_state = DATA);

  HSEL      <= '1';
  HPROT     <= HPROT_DATA or HPROT_PRIVILEGED or HPROT_NON_BUFFERABLE or HPROT_NON_CACHEABLE;
  HMASTLOCK <= '0';

  processing_13 : process (HCLK, ahb_rstn)
  begin
    if (ahb_rstn = '0') then
      HTRANS        <= HTRANS_IDLE;
      ahb_fsm_state <= IDLE;
    elsif (rising_edge(HCLK)) then
      case ((ahb_fsm_state)) is
        when IDLE =>
          if (start_toggle = '1' or start_toggle_hold = '1') then
            HTRANS        <= HTRANS_NONSEQ;
            ahb_fsm_state <= ADDRESS;
          end if;
        when ADDRESS =>
          HTRANS        <= HTRANS_IDLE;
          ahb_fsm_state <= DATA;
        when DATA =>
          if (HREADY = '1') then
            ahb_fsm_state <= IDLE;
          end if;
        when others =>
          HTRANS        <= HTRANS_IDLE;
          ahb_fsm_state <= IDLE;
      end case;
    end if;
  end process;

  -- Only single accesses; no bursts
  HBURST <= HBURST_SINGLE;
end rtl;
