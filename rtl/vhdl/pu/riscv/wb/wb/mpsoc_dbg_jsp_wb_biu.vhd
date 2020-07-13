-- Converted from rtl/verilog/wb/mpsoc_dbg_jsp_wb_biu.sv
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

use work.mpsoc_dbg_pkg.all;

entity mpsoc_dbg_jsp_wb_biu is
  port (
    -- Debug interface signals
    tck_i             : in  std_logic;
    rst_i             : in  std_logic;
    data_i            : in  std_logic_vector(7 downto 0);
    data_o            : out std_logic_vector(7 downto 0);
    bytes_available_o : out std_logic_vector(3 downto 0);
    bytes_free_o      : out std_logic_vector(3 downto 0);
    rd_strobe_i       : in  std_logic;
    wr_strobe_i       : in  std_logic;

    -- Wishbone signals
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

    int_o : out std_logic
    );
end mpsoc_dbg_jsp_wb_biu;

architecture RTL of mpsoc_dbg_jsp_wb_biu is
  component mpsoc_dbg_syncflop
    port (
      RESET : in std_logic;             -- asynchronous reset

      DEST_CLK  : in  std_logic;        -- destination clock domain clock
      D_SET     : in  std_logic;  -- synchronously set output to '1' (synchronous to dest.clock domain)
      D_RST     : in  std_logic;  -- synchronously reset output to '0' (synch. to dest.clock domain)
      TOGGLE_IN : in  std_logic;        -- toggle data from source clock domain
      D_OUT     : out std_logic         -- output (synch. to dest.clock domain)
      );
  end component;

  component mpsoc_dbg_syncreg
    port (
      CLKA     : in  std_logic;
      CLKB     : in  std_logic;
      RST      : in  std_logic;
      DATA_IN  : in  std_logic_vector(3 downto 0);
      DATA_OUT : out std_logic_vector(3 downto 0)
      );
  end component;

  component mpsoc_dbg_bytefifo
    port (
      CLK         : in  std_logic;
      RST         : in  std_logic;
      DATA_IN     : in  std_logic_vector(7 downto 0);
      DATA_OUT    : out std_logic_vector(7 downto 0);
      PUSH_POPn   : in  std_logic;
      EN          : in  std_logic;
      BYTES_AVAIL : out std_logic_vector(3 downto 0);
      BYTES_FREE  : out std_logic_vector(3 downto 0)
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --
  constant RD_IDLE  : std_logic_vector(1 downto 0) := "11";
  constant RD_PUSH  : std_logic_vector(1 downto 0) := "10";
  constant RD_POP   : std_logic_vector(1 downto 0) := "01";
  constant RD_LATCH : std_logic_vector(1 downto 0) := "00";

  constant WR_IDLE : std_logic_vector(1 downto 0) := "10";
  constant WR_PUSH : std_logic_vector(1 downto 0) := "01";
  constant WR_POP  : std_logic_vector(1 downto 0) := "00";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Registers
  signal data_in : std_logic_vector(7 downto 0);
  signal rdata   : std_logic_vector(7 downto 0);
  signal wen_tff : std_logic;
  signal ren_tff : std_logic;

  -- Wires  
  signal fifo_ack                : std_logic;
  signal wr_bytes_free           : std_logic_vector(3 downto 0);
  signal rd_bytes_avail          : std_logic_vector(3 downto 0);
  signal wr_bytes_avail          : std_logic_vector(3 downto 0);  -- used to generate wr_fifo_not_empty
  signal rd_bytes_avail_not_zero : std_logic;
  signal ren_sff_out             : std_logic;
  signal rd_fifo_data_out        : std_logic_vector(7 downto 0);
  signal data_to_extbus          : std_logic_vector(7 downto 0);
  signal data_from_extbus        : std_logic_vector(7 downto 0);
  signal wr_fifo_not_empty       : std_logic;  -- this is for the WishBone interface LSR register
  signal rx_fifo_rst             : std_logic;  -- rcvr in the WB sense, opposite most of the rest of this file
  signal tx_fifo_rst             : std_logic;  -- ditto

  -- Control Signals (FSM outputs)
  signal wda_rst   : std_logic;         -- reset wdata_avail SFF
  signal wpp       : std_logic;         -- Write FIFO PUSH (1) or POP (0)
  signal w_fifo_en : std_logic;         -- Enable write FIFO
  signal ren_rst   : std_logic;         -- reset 'pop' SFF
  signal rdata_en  : std_logic;         -- enable 'rdata' register
  signal rpp       : std_logic;         -- read FIFO PUSH (1) or POP (0)
  signal r_fifo_en : std_logic;         -- enable read FIFO    
  signal r_wb_ack  : std_logic;         -- read FSM acks WB transaction
  signal w_wb_ack  : std_logic;         -- write FSM acks WB transaction

  -- Indicators to FSMs
  signal wdata_avail : std_logic;       -- JTAG side has data available
  signal fifo_rd     : std_logic;       -- ext.bus requests read
  signal fifo_wr     : std_logic;       -- ext.bus requests write
  signal pop         : std_logic;  -- JTAG side received a byte, pop and get next
  signal rcz         : std_logic;       -- zero bytes available in read FIFO

  signal rd_fsm_state, next_rd_fsm_state : std_logic_vector(1 downto 0);
  signal wr_fsm_state, next_wr_fsm_state : std_logic_vector(1 downto 0);

  -- Interface hardware & 16550 registers
  -- Interface signals to read and write fifos:
  -- fifo_rd : read strobe
  -- fifo_wr : write strobe
  -- fifo_ack: fifo has completed operation

  --16550 registers
  signal ier : std_logic_vector(3 downto 0);
  signal iir : std_logic_vector(7 downto 0);
  -- logic [5:0] fcr;
  signal lcr : std_logic_vector(7 downto 0);
  signal mcr : std_logic_vector(7 downto 0);
  signal lsr : std_logic_vector(7 downto 0);
  signal msr : std_logic_vector(7 downto 0);
  signal scr : std_logic_vector(7 downto 0);

  signal reg_ack                : std_logic;
  signal rd_fifo_not_full       : std_logic;  -- "rd fifo" is the one the WB writes to
  signal rd_fifo_becoming_empty : std_logic;
  signal thr_int_arm            : std_logic;  -- used so that an IIR read can clear a transmit interrupt
  signal iir_read               : std_logic;

  signal rst_rd : std_logic;
  signal rst_wr : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- TCK clock domain
  -- There is no FSM here, just signal latching and clock
  -- domain synchronization

  data_o <= rdata;

  -- Write enable (WEN) toggle FF
  processing_0 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      wen_tff <= '0';
    elsif (rising_edge(tck_i)) then
      if (wr_strobe_i = '1') then
        wen_tff <= not wen_tff;
      end if;
    end if;
  end process;

  -- Read enable (REN) toggle FF
  processing_1 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      ren_tff <= '0';
    elsif (rising_edge(tck_i)) then
      if (rd_strobe_i = '1') then
        ren_tff <= not ren_tff;
      end if;
    end if;
  end process;

  -- Write data register
  processing_2 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      data_in <= X"00";
    elsif (rising_edge(tck_i)) then
      if (wr_strobe_i = '1') then
        data_in <= data_i;
      end if;
    end if;
  end process;

  -- Wishbone clock domain

  -- Combinatorial assignments
  rd_bytes_avail_not_zero <= reduce_or(rd_bytes_avail);
  pop                     <= ren_sff_out and rd_bytes_avail_not_zero;
  rcz                     <= not rd_bytes_avail_not_zero;
  fifo_ack                <= r_wb_ack or w_wb_ack;
  wr_fifo_not_empty       <= reduce_or(wr_bytes_avail);

  -- rdata register
  processing_3 : process (wb_clk_i, rst_i)
  begin
    if (rst_i = '1') then
      rdata <= X"00";
    elsif (rising_edge(wb_clk_i)) then
      if (rdata_en = '1') then
        rdata <= rd_fifo_data_out;
      end if;
    end if;
  end process;

  -- WEN SFF
  wen_sff : mpsoc_dbg_syncflop
    port map (
      RESET     => rst_i,
      DEST_CLK  => wb_clk_i,
      D_SET     => '0',
      D_RST     => wda_rst,
      TOGGLE_IN => wen_tff,
      D_OUT     => wdata_avail
      );

  -- REN SFF
  ren_sff : mpsoc_dbg_syncflop
    port map (
      RESET     => rst_i,
      DEST_CLK  => wb_clk_i,
      D_SET     => '0',
      D_RST     => ren_rst,
      TOGGLE_IN => ren_tff,
      D_OUT     => ren_sff_out
      );

  --TODO syncreg.RST should be synchronised to DFF clock domain
  -- 'free space available' syncreg
  freespace_syncreg : mpsoc_dbg_syncreg
    port map (
      RST      => rst_i,
      CLKA     => wb_clk_i,
      CLKB     => tck_i,
      DATA_IN  => wr_bytes_free,
      DATA_OUT => bytes_free_o
      );

  -- 'bytes available' syncreg
  bytesavail_syncreg : mpsoc_dbg_syncreg
    port map (
      RST      => rst_i,
      CLKA     => wb_clk_i,
      CLKB     => tck_i,
      DATA_IN  => rd_bytes_avail,
      DATA_OUT => bytes_available_o
      );

  --TODO synch. FIFO resets
  -- write FIFO
  wr_fifo : mpsoc_dbg_bytefifo
    port map (
      RST         => rst_wr,  -- rst_i from JTAG clk domain, rx_fifo_rst from WB, RST is async reset
      CLK         => wb_clk_i,
      DATA_IN     => data_in,
      DATA_OUT    => data_to_extbus,
      PUSH_POPn   => wpp,
      EN          => w_fifo_en,
      BYTES_AVAIL => wr_bytes_avail,
      BYTES_FREE  => wr_bytes_free
      );

  rst_wr <= rst_i or rx_fifo_rst;

  -- read FIFO
  rd_fifo : mpsoc_dbg_bytefifo
    port map (
      RST         => rst_rd,  -- rst_i from JTAG clk domain, tx_fifo_rst from WB, RST is async reset
      CLK         => wb_clk_i,
      DATA_IN     => data_from_extbus,
      DATA_OUT    => rd_fifo_data_out,
      PUSH_POPn   => rpp,
      EN          => r_fifo_en,
      BYTES_AVAIL => rd_bytes_avail,
      BYTES_FREE  => open
      );

  rst_rd <= rst_i or tx_fifo_rst;

  -- State machine for the read FIFO

  -- Sequential bit
  processing_4 : process (wb_clk_i, rst_i)
  begin
    if (rst_i = '1') then
      rd_fsm_state <= RD_IDLE;
    elsif (rising_edge(wb_clk_i)) then
      rd_fsm_state <= next_rd_fsm_state;
    end if;
  end process;

  -- Determination of next state (combinatorial)
  processing_5 : process (rd_fsm_state)
  begin
    case (rd_fsm_state) is
      when RD_IDLE =>
        if (fifo_wr = '1') then
          next_rd_fsm_state <= RD_PUSH;
        elsif (pop = '1') then
          next_rd_fsm_state <= RD_POP;
        else
          next_rd_fsm_state <= RD_IDLE;
        end if;
      when RD_PUSH =>
        -- putting first item in fifo, move to rdata in state LATCH
        if (rcz = '1') then
          next_rd_fsm_state <= RD_LATCH;
        elsif (pop = '1') then
          next_rd_fsm_state <= RD_POP;
        else
          next_rd_fsm_state <= RD_IDLE;
        end if;
      when RD_POP =>
        -- new data at FIFO head, move to rdata in state LATCH
        next_rd_fsm_state <= RD_LATCH;
      when RD_LATCH =>
        if (fifo_wr = '1') then
          next_rd_fsm_state <= RD_PUSH;
        elsif (pop = '1') then
          next_rd_fsm_state <= RD_POP;
        else
          next_rd_fsm_state <= RD_IDLE;
        end if;
      when others =>
        next_rd_fsm_state <= RD_IDLE;
    end case;
  end process;

  -- Outputs of state machine (combinatorial)
  processing_6 : process (rd_fsm_state)
  begin
    ren_rst   <= '0';
    rpp       <= '0';
    r_fifo_en <= '0';
    rdata_en  <= '0';
    r_wb_ack  <= '0';
    case (rd_fsm_state) is
      when RD_PUSH =>
        rpp       <= '1';
        r_fifo_en <= '1';
        r_wb_ack  <= '1';
      when RD_POP =>
        ren_rst   <= '1';
        r_fifo_en <= '1';
      when RD_LATCH =>
        rdata_en <= '1';
      when others =>
        null;
    end case;
  end process;

  -- State machine for the write FIFO

  -- Sequential bit
  processing_7 : process (wb_clk_i, rst_i)
  begin
    if (rst_i = '1') then
      wr_fsm_state <= WR_IDLE;
    elsif (rising_edge(wb_clk_i)) then
      wr_fsm_state <= next_wr_fsm_state;
    end if;
  end process;

  -- Determination of next state (combinatorial)
  processing_8 : process (wr_fsm_state)
  begin
    case (wr_fsm_state) is
      when WR_IDLE =>
        if (fifo_rd = '1') then
          next_wr_fsm_state <= WR_POP;
        elsif (wdata_avail = '1') then
          next_wr_fsm_state <= WR_PUSH;
        else
          next_wr_fsm_state <= WR_IDLE;
        end if;
      when WR_PUSH =>
        if (fifo_rd = '1') then
          next_wr_fsm_state <= WR_POP;
        else
          next_wr_fsm_state <= WR_IDLE;
        end if;
      when WR_POP =>
        if (wdata_avail = '1') then
          next_wr_fsm_state <= WR_PUSH;
        else
          next_wr_fsm_state <= WR_IDLE;
        end if;
      when others =>
        next_wr_fsm_state <= WR_IDLE;
    end case;
  end process;

  -- Outputs of state machine (combinatorial)
  processing_9 : process (wr_fsm_state)
  begin
    wda_rst   <= '0';
    wpp       <= '0';
    w_fifo_en <= '0';
    w_wb_ack  <= '0';
    case (wr_fsm_state) is
      when WR_PUSH =>
        wda_rst   <= '1';
        wpp       <= '1';
        w_fifo_en <= '1';
      when WR_POP =>
        w_wb_ack  <= '1';
        w_fifo_en <= '1';
      when others =>
        null;
    end case;
  end process;

  -- These 16550 registers are not implemented
  mcr <= X"00";
  msr <= X"0b";

  -- Create the simple / combinatorial registers
  rd_fifo_not_full <= not to_stdlogic(rd_bytes_avail = X"8");
  lsr              <= ('0' & rd_fifo_not_full & rd_fifo_not_full & X"0" & wr_fifo_not_empty);

  -- Create writeable registers
  processing_10 : process (wb_clk_i)
  begin
    if (rising_edge(wb_clk_i)) then
      if (wb_rst_i = '1') then
        ier <= X"0";
        lcr <= X"00";
        scr <= X"00";
      elsif (wb_cyc_i = '1' and wb_stb_i = '1' and wb_we_i = '1') then
        case ((wb_adr_i)) is
          when "001" =>
            if (lcr(7) = '0') then
              ier <= wb_dat_i(3 downto 0);
            end if;
          when "011" =>
            lcr <= wb_dat_i;
          when "111" =>
            scr <= wb_dat_i;
          when others =>
            null;
        end case;
      end if;
    end if;
  end process;

  -- Create handshake signals to/from the FIFOs
  fifo_rd <= wb_cyc_i and wb_stb_i and not wb_we_i and to_stdlogic(wb_adr_i = "000") and not lcr(7);
  fifo_wr <= wb_cyc_i and wb_stb_i and wb_we_i and to_stdlogic(wb_adr_i = "000") and not lcr(7);

  -- Wishbone responses
  wb_ack_o <= fifo_ack or reg_ack;
  wb_err_o <= '0';

  -- acknowledge all accesses, except to FIFOs
  reg_ack <= wb_cyc_i and wb_stb_i and (lcr(7) or to_stdlogic(wb_adr_i /= "000"));

  -- Create FIFO reset signals
  rx_fifo_rst <= wb_cyc_i and wb_stb_i and wb_we_i and to_stdlogic(wb_adr_i = "010") and wb_dat_i(1);
  tx_fifo_rst <= wb_cyc_i and wb_stb_i and wb_we_i and to_stdlogic(wb_adr_i = "010") and wb_dat_i(2);

  -- Create IIR (and THR INT arm bit)
  rd_fifo_becoming_empty <= r_fifo_en and (not rpp) and to_stdlogic(rd_bytes_avail = X"1");  -- "rd fifo" is the ext.bus write FIFO...

  iir_read <= wb_cyc_i and wb_stb_i and not wb_we_i and to_stdlogic(wb_adr_i = "010");

  processing_11 : process (wb_clk_i)
  begin
    if (rising_edge(wb_clk_i)) then
      if (wb_rst_i = '1') then
        thr_int_arm <= '0';
      elsif (fifo_wr = '1' or rd_fifo_becoming_empty = '1') then  -- Set when WB write fifo becomes empty, or on a write to it
        thr_int_arm <= '1';
      elsif (iir_read = '1' and wr_fifo_not_empty = '0') then
        thr_int_arm <= '0';
      end if;
    end if;
  end process;

  processing_12 : process (wr_fifo_not_empty)
  begin
    if (wr_fifo_not_empty = '1') then
      iir <= "00000100";
    elsif (thr_int_arm = '1' and rd_fifo_not_full = '1') then
      iir <= "00000010";
    else
      iir <= "00000001";
    end if;
  end process;

  -- Create ext.bus Data Out
  processing_13 : process (wb_adr_i)
  begin
    case (wb_adr_i) is
      when "000" =>
        wb_dat_o <= data_to_extbus;
      when "001" =>
        wb_dat_o <= (X"0" & ier);
      when "010" =>
        wb_dat_o <= iir;
      when "011" =>
        wb_dat_o <= lcr;
      when "100" =>
        wb_dat_o <= mcr;
      when "101" =>
        wb_dat_o <= lsr;
      when "110" =>
        wb_dat_o <= msr;
      when "111" =>
        wb_dat_o <= scr;
      when others =>
        wb_dat_o <= X"00";
    end case;
  end process;

  data_from_extbus <= wb_dat_i;  -- Data to the FIFO

  -- Generate interrupt output
  int_o <= (rd_fifo_not_full and thr_int_arm and ier(1)) or (wr_fifo_not_empty and ier(0));
end RTL;
