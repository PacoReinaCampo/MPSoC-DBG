-- Converted from rtl/verilog/core/mpsoc_dbg_jsp_module_core.sv
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

entity mpsoc_dbg_jsp_module_core is
  generic (
    DBG_JSP_DATAREG_LEN : integer := 64
    );
  port (
    rst_i : in std_logic;

    -- JTAG signals
    tck_i        : in  std_logic;
    tdi_i        : in  std_logic;
    module_tdo_o : out std_logic;

    -- TAP states
    capture_dr_i : in std_logic;
    shift_dr_i   : in std_logic;
    update_dr_i  : in std_logic;

    data_register_i : in  std_logic_vector(DBG_JSP_DATAREG_LEN-1 downto 0);  -- the data register is at top level, shared between all modules
    module_select_i : in  std_logic;
    top_inhibit_o   : out std_logic;

    -- JSP BIU interface
    biu_clk             : out std_logic;
    biu_rst             : out std_logic;
    biu_di              : out std_logic_vector(7 downto 0);  -- data towards BIU
    biu_do              : in  std_logic_vector(7 downto 0);  -- data from BIU
    biu_space_available : in  std_logic_vector(3 downto 0);
    biu_bytes_available : in  std_logic_vector(3 downto 0);
    biu_rd_strobe       : out std_logic;  -- Indicates that the BIU should ACK last read operation + start another
    biu_wr_strobe       : out std_logic  -- Indicates BIU should latch input + begin a write operation
    );
end mpsoc_dbg_jsp_module_core;

architecture RTL of mpsoc_dbg_jsp_module_core is
  -- NOTE:  For the rest of this file, "input" and the "in" direction refer to bytes being transferred
  -- from the PC, through the JTAG, and into the BIU FIFO.  The "output" direction refers to data being
  -- transferred from the BIU FIFO, through the JTAG to the PC.

  -- The read and write bit counts are separated to allow for JTAG chains with multiple devices.
  -- The read bit count starts right away (after a single throwaway bit), but the write count
  -- waits to receive a '1' start bit.

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  --FSM states
  constant STATE_WR_IDLE   : std_logic_vector(1 downto 0) := "11";
  constant STATE_WR_WAIT   : std_logic_vector(1 downto 0) := "10";
  constant STATE_WR_COUNTS : std_logic_vector(1 downto 0) := "01";
  constant STATE_WR_XFER   : std_logic_vector(1 downto 0) := "00";

  constant STATE_RD_IDLE   : std_logic_vector(1 downto 0) := "11";
  constant STATE_RD_COUNTS : std_logic_vector(1 downto 0) := "10";
  constant STATE_RD_RDACK  : std_logic_vector(1 downto 0) := "01";
  constant STATE_RD_XFER   : std_logic_vector(1 downto 0) := "00";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Registers to hold state etc.
  signal read_bit_count     : std_logic_vector(3 downto 0);  -- How many bits have been shifted out
  signal write_bit_count    : std_logic_vector(3 downto 0);  -- How many bits have been shifted in
  signal input_word_count   : std_logic_vector(3 downto 0);  -- space (bytes) remaining in input FIFO (from JTAG)
  signal output_word_count  : std_logic_vector(3 downto 0);  -- bytes remaining in output FIFO (to JTAG)
  signal user_word_count    : std_logic_vector(3 downto 0);  -- bytes user intends to send from PC
  signal data_out_shift_reg : std_logic_vector(7 downto 0);  -- parallel-load output shift register

  -- Control signals for the various counters / registers / state machines
  signal rd_bit_ct_en     : std_logic;  -- enable bit counter
  signal rd_bit_ct_rst    : std_logic;  -- reset (zero) bit count register
  signal wr_bit_ct_en     : std_logic;  -- enable bit counter
  signal wr_bit_ct_rst    : std_logic;  -- reset (zero) bit count register   
  signal in_word_ct_sel   : std_logic;  -- Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
  signal out_word_ct_sel  : std_logic;  -- Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
  signal in_word_ct_en    : std_logic;  -- Enable input byte counter register
  signal out_word_ct_en   : std_logic;  -- Enable output byte count register
  signal user_word_ct_en  : std_logic;  -- Enable user byte count registere
  signal user_word_ct_sel : std_logic;  -- selects data for user byte counter.  0 = user data, 1 = decremented byte count
  signal out_reg_ld_en    : std_logic;  -- Enable parallel load of data_out_shift_reg
  signal out_reg_shift_en : std_logic;  -- Enable shift of data_out_shift_reg
  signal out_reg_data_sel : std_logic;  -- 0 = BIU data, 1 = byte count data (also from BIU)

  -- Status signals
  signal in_word_count_zero   : std_logic;  -- true when input byte counter is zero
  signal out_word_count_zero  : std_logic;  -- true when output byte counter is zero
  signal user_word_count_zero : std_logic;  -- true when user byte counter is zero
  signal rd_bit_count_max     : std_logic;  -- true when bit counter is equal to current word size
  signal wr_bit_count_max     : std_logic;  -- true when bit counter is equal to current word size

  -- Intermediate signals
  signal data_to_in_word_counter   : std_logic_vector(3 downto 0);  -- output of the mux in front of the input byte counter reg
  signal data_to_out_word_counter  : std_logic_vector(3 downto 0);  -- output of the mux in front of the output byte counter reg
  signal data_to_user_word_counter : std_logic_vector(3 downto 0);  -- output of mux in front of user word counter
  signal count_data_in             : std_logic_vector(3 downto 0);  -- from data_register_i
  signal data_to_biu               : std_logic_vector(7 downto 0);  -- from data_register_i
  signal data_from_biu             : std_logic_vector(7 downto 0);  -- to data_out_shift_register
  signal count_data_from_biu       : std_logic_vector(7 downto 0);  -- combined space avail / bytes avail
  signal out_reg_data              : std_logic_vector(7 downto 0);  -- parallel input to the output shift register

  --Statemachine
  signal wr_module_state, wr_module_next_state : std_logic_vector(1 downto 0);
  signal rd_module_state, rd_module_next_state : std_logic_vector(1 downto 0);

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Combinatorial assignments
  count_data_from_biu <= (biu_bytes_available & biu_space_available);
  count_data_in       <= (tdi_i & data_register_i(DBG_JSP_DATAREG_LEN-1 downto DBG_JSP_DATAREG_LEN-3));  -- Second nibble of user data
  data_to_biu         <= (tdi_i & data_register_i(DBG_JSP_DATAREG_LEN-1 downto DBG_JSP_DATAREG_LEN-7));
  top_inhibit_o       <= '0';

  -- Input bit counter
  processing_0 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      write_bit_count <= X"0";
    elsif (rising_edge(tck_i)) then
      if (wr_bit_ct_rst = '1') then
        write_bit_count <= X"0";
      elsif (wr_bit_ct_en = '1') then
        write_bit_count <= std_logic_vector(unsigned(write_bit_count)+X"1");
      end if;
    end if;
  end process;

  wr_bit_count_max <= to_stdlogic(write_bit_count = X"7");

  -- Output bit counter
  processing_1 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      read_bit_count <= X"0";
    elsif (rising_edge(tck_i)) then
      if (rd_bit_ct_rst = '1') then
        read_bit_count <= X"0";
      elsif (rd_bit_ct_en = '1') then
        read_bit_count <= std_logic_vector(unsigned(read_bit_count)+X"1");
      end if;
    end if;
  end process;

  rd_bit_count_max <= to_stdlogic(read_bit_count = X"7");

  -- Input word counter
  data_to_in_word_counter <= std_logic_vector(unsigned(input_word_count)-X"1")
                             when in_word_ct_sel = '1' else biu_space_available;

  processing_2 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      input_word_count <= X"0";
    elsif (rising_edge(tck_i)) then
      if (in_word_ct_en = '1') then
        input_word_count <= data_to_in_word_counter;
      end if;
    end if;
  end process;

  in_word_count_zero <= to_stdlogic(input_word_count = X"0");

  -- Output word counter
  data_to_out_word_counter <= std_logic_vector(unsigned(output_word_count)-X"1")
                              when out_word_ct_sel = '1' else biu_bytes_available;

  processing_3 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      output_word_count <= X"0";
    elsif (rising_edge(tck_i)) then
      if (out_word_ct_en = '1') then
        output_word_count <= data_to_out_word_counter;
      end if;
    end if;
  end process;

  out_word_count_zero <= reduce_nor(output_word_count);

  -- User word counter
  data_to_user_word_counter <= std_logic_vector(unsigned(user_word_count)-X"1")
                               when user_word_ct_sel = '1' else count_data_in;

  processing_4 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      user_word_count <= X"0";
    elsif (rising_edge(tck_i)) then
      if (user_word_ct_en = '1') then
        user_word_count <= data_to_user_word_counter;
      end if;
    end if;
  end process;

  user_word_count_zero <= reduce_nor(user_word_count);

  -- Output register and TDO output MUX
  out_reg_data <= count_data_from_biu
                  when out_reg_data_sel = '1' else data_from_biu;

  processing_5 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      data_out_shift_reg <= X"00";
    elsif (rising_edge(tck_i)) then
      if (out_reg_ld_en = '1') then
        data_out_shift_reg <= out_reg_data;
      elsif (out_reg_shift_en = '1') then
        data_out_shift_reg <= ('0' & data_out_shift_reg(7 downto 1));
      end if;
    end if;
  end process;

  module_tdo_o <= data_out_shift_reg(0);

  -- Bus Interface Unit (to JTAG / WB UART)
  -- It is assumed that the BIU has internal registers, and will
  -- latch write data (and ack read data) on rising clock edge 
  -- when strobe is asserted
  biu_clk       <= tck_i;
  biu_rst       <= rst_i;
  biu_di        <= data_to_biu;
  data_from_biu <= biu_do;

--   mpsoc_dbg_jsp_biu jsp_biu_i (
--    // Debug interface signals
--    .tck_i           (tck_i),
--    .rst_i           (rst_i),
--    .data_i          (data_to_biu),
--    .data_o          (data_from_biu),
--    .bytes_available_o (biu_bytes_available),
--    .bytes_free_o    (biu_space_available),
--    .rd_strobe_i     (biu_rd_strobe),
--    .wr_strobe_i     (biu_wr_strobe),
--
--    // Wishbone slave signals
--    .wb_clk_i        (wb_clk_i),
--    .wb_rst_i        (wb_rst_i),
--    .wb_adr_i        (wb_adr_i),
--    .wb_dat_o        (wb_dat_o),
--    .wb_dat_i        (wb_dat_i),
--    .wb_cyc_i        (wb_cyc_i),
--    .wb_stb_i        (wb_stb_i),
--    .wb_sel_i        (wb_sel_i),
--    .wb_we_i         (wb_we_i),
--    .wb_ack_o        (wb_ack_o),
--    .wb_err_o        (wb_err_o),
--    .wb_cti_i        (wb_cti_i),
--    .wb_bte_i        (wb_bte_i),
--    .int_o           (int_o)
--  );

  -- Input Control FSM

  -- sequential part of the FSM
  processing_6 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      wr_module_state <= STATE_WR_IDLE;
    elsif (rising_edge(tck_i)) then
      wr_module_state <= wr_module_next_state;
    end if;
  end process;

  -- Determination of next state; purely combinatorial
  processing_7 : process (wr_module_state)
  begin
    case (wr_module_state) is
      when STATE_WR_IDLE =>
        if (module_select_i = '1' and capture_dr_i = '1') then
          wr_module_next_state <= STATE_WR_COUNTS;
        else
          wr_module_next_state <= STATE_WR_IDLE;
        end if;
      when STATE_WR_WAIT =>
        if (update_dr_i = '1') then
          wr_module_next_state <= STATE_WR_IDLE;
        elsif (module_select_i = '1' and tdi_i = '1') then  -- got start bit
          wr_module_next_state <= STATE_WR_COUNTS;
        else
          wr_module_next_state <= STATE_WR_WAIT;
        end if;
      when STATE_WR_COUNTS =>
        if (update_dr_i = '1') then
          wr_module_next_state <= STATE_WR_IDLE;
        elsif (wr_bit_count_max = '1') then
          wr_module_next_state <= STATE_WR_XFER;
        else
          wr_module_next_state <= STATE_WR_COUNTS;
        end if;
      when STATE_WR_XFER =>
        if (update_dr_i = '1') then
          wr_module_next_state <= STATE_WR_IDLE;
        else
          wr_module_next_state <= STATE_WR_XFER;
        end if;
      when others =>
        -- shouldn't actually happen...
        wr_module_next_state <= STATE_WR_IDLE;
    end case;
  end process;

  -- Outputs of state machine, pure combinatorial
  processing_8 : process (wr_module_state)
  begin
    -- Default everything to 0, keeps the case statement simple
    wr_bit_ct_en     <= '0';            -- enable bit counter
    wr_bit_ct_rst    <= '0';            -- reset (zero) bit count register
    in_word_ct_sel   <= '0';  -- Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    user_word_ct_sel <= '0';  -- selects data for user byte counter, 0 = user data, 1 = decremented count
    in_word_ct_en    <= '0';            -- Enable input byte counter register
    user_word_ct_en  <= '0';            -- enable user byte count register
    biu_wr_strobe    <= '0';  -- Indicates BIU should latch input + begin a write operation

    case (wr_module_state) is
      when STATE_WR_IDLE =>
        in_word_ct_sel <= '0';
        -- Going to transfer; enable count registers and output register
        if (wr_module_next_state /= STATE_WR_IDLE) then
          wr_bit_ct_rst <= '1';
          in_word_ct_en <= '1';
        end if;
      -- This state is only used when support for multi-device JTAG chains is enabled.
      when STATE_WR_WAIT =>
        -- Don't do anything, just wait for the start bit.
        wr_bit_ct_en <= '0';
      when STATE_WR_COUNTS =>
        -- Don't do anything in PAUSE or EXIT states...
        if (shift_dr_i = '1') then
          wr_bit_ct_en     <= '1';
          user_word_ct_sel <= '0';

          if (wr_bit_count_max = '1') then
            wr_bit_ct_rst   <= '1';
            user_word_ct_en <= '1';
          end if;
        end if;
      when STATE_WR_XFER =>
        -- Don't do anything in PAUSE or EXIT states
        if (shift_dr_i = '1') then
          wr_bit_ct_en     <= '1';
          in_word_ct_sel   <= '1';
          user_word_ct_sel <= '1';

          if (wr_bit_count_max = '1') then  -- Start biu transactions, if word counts allow
            wr_bit_ct_rst <= '1';

            if ((in_word_count_zero or user_word_count_zero) = '0') then
              biu_wr_strobe   <= '1';
              in_word_ct_en   <= '1';
              user_word_ct_en <= '1';
            end if;
          end if;
        end if;
      when others =>
        null;
    end case;
  end process;

  -- Output Control FSM

  -- We do not send the equivalent of a 'start bit' (like the one the input FSM
  -- waits for when support for multi-device JTAG chains is enabled).  Since the
  -- input and output are going to be offset anyway, why bother...

  -- sequential part of the FSM
  processing_9 : process (tck_i, rst_i)
  begin
    if (rst_i = '1') then
      rd_module_state <= STATE_RD_IDLE;
    elsif (rising_edge(tck_i)) then
      rd_module_state <= rd_module_next_state;
    end if;
  end process;

  -- Determination of next state; purely combinatorial
  processing_10 : process (rd_module_state)
  begin
    case (rd_module_state) is
      when STATE_RD_IDLE =>
        if (module_select_i = '1' and capture_dr_i = '1') then
          rd_module_next_state <= STATE_RD_COUNTS;
        else
          rd_module_next_state <= STATE_RD_IDLE;
        end if;
      when STATE_RD_COUNTS =>
        if (update_dr_i = '1') then
          rd_module_next_state <= STATE_RD_IDLE;
        elsif (rd_bit_count_max = '1') then
          rd_module_next_state <= STATE_RD_RDACK;
        else
          rd_module_next_state <= STATE_RD_COUNTS;
        end if;
      when STATE_RD_RDACK =>
        if (update_dr_i = '1') then
          rd_module_next_state <= STATE_RD_IDLE;
        else
          rd_module_next_state <= STATE_RD_XFER;
        end if;
      when STATE_RD_XFER =>
        if (update_dr_i = '1') then
          rd_module_next_state <= STATE_RD_IDLE;
        elsif (rd_bit_count_max = '1') then
          rd_module_next_state <= STATE_RD_RDACK;
        else
          rd_module_next_state <= STATE_RD_XFER;
        end if;
      when others =>
        -- shouldn't actually happen...
        rd_module_next_state <= STATE_RD_IDLE;
    end case;
  end process;

  -- Outputs of state machine, pure combinatorial
  processing_11 : process (rd_module_state)
  begin
    -- Default everything to 0, keeps the case statement simple
    rd_bit_ct_en     <= '0';            -- enable bit counter
    rd_bit_ct_rst    <= '0';            -- reset (zero) bit count register
    out_word_ct_sel  <= '0';  -- Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    out_word_ct_en   <= '0';            -- Enable output byte count register
    out_reg_ld_en    <= '0';  -- Enable parallel load of data_out_shift_reg
    out_reg_shift_en <= '0';            -- Enable shift of data_out_shift_reg
    out_reg_data_sel <= '0';  -- 0 = BIU data, 1 = byte count data (also from BIU)
    biu_rd_strobe    <= '0';  -- Indicates that the bus unit should ACK the last read operation + start another

    case (rd_module_state) is
      when STATE_RD_IDLE =>
        out_reg_data_sel <= '1';
        out_word_ct_sel  <= '0';
        -- Going to transfer; enable count registers and output register
        if (rd_module_next_state /= STATE_RD_IDLE) then
          out_reg_ld_en  <= '1';
          rd_bit_ct_rst  <= '1';
          out_word_ct_en <= '1';
        end if;
      when STATE_RD_COUNTS =>
        -- Don't do anything in PAUSE or EXIT states...
        if (shift_dr_i = '1') then
          rd_bit_ct_en     <= '1';
          out_reg_shift_en <= '1';

          if (rd_bit_count_max = '1') then
            rd_bit_ct_rst <= '1';

            -- Latch the next output word, but don't ack until STATE_RD_RDACK
            if (out_word_count_zero = '0') then
              out_reg_ld_en    <= '1';
              out_reg_shift_en <= '0';
            end if;
          end if;
        end if;
      when STATE_RD_RDACK =>
        -- Don't do anything in PAUSE or EXIT states
        if (shift_dr_i = '1') then
          rd_bit_ct_en     <= '1';
          out_reg_shift_en <= '1';
          out_reg_data_sel <= '0';

          -- Never have to worry about bit_count_max here.
          if (out_word_count_zero = '0') then
            biu_rd_strobe <= '1';
          end if;
        end if;
      when STATE_RD_XFER =>
        -- Don't do anything in PAUSE or EXIT states
        if (shift_dr_i = '1') then
          rd_bit_ct_en     <= '1';
          out_word_ct_sel  <= '1';
          out_reg_shift_en <= '1';
          out_reg_data_sel <= '0';

          if (rd_bit_count_max = '1') then  -- Start biu transaction, if word count allows
            rd_bit_ct_rst <= '1';
            -- Don't ack the read byte here, we do it in STATE_RDACK
            if (out_word_count_zero = '0') then
              out_reg_ld_en    <= '1';
              out_reg_shift_en <= '0';
              out_word_ct_en   <= '1';
            end if;
          end if;
        end if;
      when others =>
        null;
    end case;
  end process;
end RTL;
