-- Converted from rtl/verilog/core/mpsoc_dbg_bus_module_core.sv
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

entity mpsoc_dbg_bus_module_core is
  generic (
    --parameter such that these can be pushed down from the higher level
    --higher level will either read these from a package or get them as parameters

    --Data + Address width
    ADDR_WIDTH : integer := 32;
    DATA_WIDTH : integer := 32;

    --Data register size (function of ADDR_WIDTH)
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

    --Bus Interface Unit ports
    biu_clk       : out std_logic;
    biu_rst       : out std_logic;      --BIU reset
    biu_di        : out std_logic_vector(DATA_WIDTH-1 downto 0);  --data towards BIU
    biu_do        : in  std_logic_vector(DATA_WIDTH-1 downto 0);  --data from BIU
    biu_addr      : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    biu_strb      : out std_logic;
    biu_rw        : out std_logic;
    biu_rdy       : in  std_logic;
    biu_err       : in  std_logic;
    biu_word_size : out std_logic_vector(3 downto 0)
    );
end mpsoc_dbg_bus_module_core;

architecture RTL of mpsoc_dbg_bus_module_core is
  component mpsoc_dbg_crc32
    port (
      rstn       : in  std_logic;
      clk        : in  std_logic;
      data       : in  std_logic;
      enable     : in  std_logic;
      shift      : in  std_logic;
      clr        : in  std_logic;
      crc_out    : out std_logic_vector(31 downto 0);
      serial_out : out std_logic
      );
  end component;

  --////////////////////////////////////////////////////////////////
  --
  -- Constants
  --

  --Instructions
  constant BWRITE8  : std_logic_vector(3 downto 0) := X"1";
  constant BWRITE16 : std_logic_vector(3 downto 0) := X"2";
  constant BWRITE32 : std_logic_vector(3 downto 0) := X"3";
  constant BWRITE64 : std_logic_vector(3 downto 0) := X"4";
  constant BREAD8   : std_logic_vector(3 downto 0) := X"5";
  constant BREAD16  : std_logic_vector(3 downto 0) := X"6";
  constant BREAD32  : std_logic_vector(3 downto 0) := X"7";
  constant BREAD64  : std_logic_vector(3 downto 0) := X"8";
  constant IREG_WR  : std_logic_vector(3 downto 0) := X"9";
  constant IREG_SEL : std_logic_vector(3 downto 0) := X"d";

  constant REGSELECT_SIZE : integer := 2;

  constant STATE_IDLE    : std_logic_vector(3 downto 0) := "1011";
  constant STATE_RBEGIN  : std_logic_vector(3 downto 0) := "1010";
  constant STATE_RREADY  : std_logic_vector(3 downto 0) := "1001";
  constant STATE_RSTATUS : std_logic_vector(3 downto 0) := "1000";
  constant STATE_RBURST  : std_logic_vector(3 downto 0) := "0111";
  constant STATE_WREADY  : std_logic_vector(3 downto 0) := "0110";
  constant STATE_WWAIT   : std_logic_vector(3 downto 0) := "0101";
  constant STATE_WBURST  : std_logic_vector(3 downto 0) := "0100";
  constant STATE_WSTATUS : std_logic_vector(3 downto 0) := "0011";
  constant STATE_RCRC    : std_logic_vector(3 downto 0) := "0010";
  constant STATE_WCRC    : std_logic_vector(3 downto 0) := "0001";
  constant STATE_WMATCH  : std_logic_vector(3 downto 0) := "0000";

  constant INTREG_ERROR : std_logic_vector(REGSELECT_SIZE-1 downto 0) := (others => '0');

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Registers to hold state etc.
  signal address_counter          : std_logic_vector(ADDR_WIDTH-1 downto 0);  -- Holds address for next Wishbone access
  signal bit_count                : std_logic_vector(5 downto 0);  -- How many bits have been shifted in/out
  signal word_count               : std_logic_vector(15 downto 0);  -- bytes remaining in current burst command
  signal data_out_shift_reg       : std_logic_vector(DATA_WIDTH downto 0);  -- 32 bits to accomodate the internal_reg_error
  signal internal_register_select : std_logic_vector(REGSELECT_SIZE-1 downto 0);  -- Holds index of currently selected register
  signal internal_reg_error       : std_logic_vector(ADDR_WIDTH downto 0);  -- WB error module internal register.  32 bit address + error bit (LSB)

  -- Control signals for the various counters / registers / state machines
  signal addr_sel         : std_logic;  -- Selects data for address_counter. 0=data_register_i, 1=incremented address count
  signal addr_ct_en       : std_logic;  -- Enable signal for address counter register
  signal op_reg_en        : std_logic;  -- Enable signal for 'operation' register
  signal bit_ct_en        : std_logic;  -- enable bit counter
  signal bit_ct_rst       : std_logic;  -- reset (zero) bit count register
  signal word_ct_sel      : std_logic;  -- Selects data for byte counter.  0=data_register_i, 1=decremented byte count
  signal word_ct_en       : std_logic;  -- Enable byte counter register
  signal out_reg_ld_en    : std_logic;  -- Enable parallel load of data_out_shift_reg
  signal out_reg_shift_en : std_logic;  -- Enable shift of data_out_shift_reg
  signal out_reg_data_sel : std_logic;  -- 0 = BIU data, 1 = internal register data
  signal tdo_output_sel   : std_logic_vector(3 downto 0);  -- Selects signal to send to TDO. 0=ready bit, 1=output register, 2=CRC match, 3=CRC shift reg.
  signal biu_strobe       : std_logic;  -- Indicates that the bus unit should latch data and start a transaction
  signal crc_clr          : std_logic;  -- resets CRC module
  signal crc_en           : std_logic;  -- does 1-bit iteration in CRC module
  signal crc_in_sel       : std_logic;  -- selects incoming write data (=0) or outgoing read data (=1)as input to CRC module
  signal crc_shift_en     : std_logic;  -- CRC reg is also it's own output shift register; this enables a shift
  signal regsel_ld_en     : std_logic;  -- Reg. select register load enable
  signal intreg_ld_en     : std_logic;  -- load enable for internal registers
  signal error_reg_en     : std_logic;  -- Tells the error register to check for and latch a bus error
  signal biu_clr_err      : std_logic;  -- Allows FSM to reset BIU, to clear the biu_err bit which may have been set on the last transaction of the last burst.

  -- Status signals
  signal word_count_zero    : std_logic;  -- true when byte counter is zero
  signal bit_count_max      : std_logic;  -- true when bit counter is equal to current word size
  signal module_cmd         : std_logic;  -- inverse of MSB of data_register. 1 means current cmd not for top level (but is for us)
  signal burst_read         : std_logic;
  signal burst_write        : std_logic;
  signal intreg_instruction : std_logic;  -- True when the input_data reg has a valid internal register instruction
  signal intreg_write       : std_logic;  -- True when the input_data reg has an internal register write op
  signal rd_op              : std_logic;  -- True when operation in the opcode reg is a read, false when a write
  signal crc_match          : std_logic;  -- indicates whether data_register matches computed CRC
  signal bit_count_32       : std_logic;  -- true when bit count register == 32, for CRC after burst writes

  -- Intermediate signals
  signal word_size_bits         : std_logic_vector(5 downto 0);  -- 8,16,32,64.  Decoded from 'operation'
  signal word_size_bytes        : std_logic_vector(3 downto 0);  -- 1,2,4,8
  signal decremented_word_count : std_logic_vector(15 downto 0);
  signal address_data_in        : std_logic_vector(ADDR_WIDTH-1 downto 0);  -- from data_register_i
  signal count_data_in          : std_logic_vector(15 downto 0);  -- from data_register_i
  signal operation_in           : std_logic_vector(3 downto 0);  -- from data_register_i
  signal data_to_biu            : std_logic_vector(DATA_WIDTH-1 downto 0);  -- from data_register_i
  signal crc_data_out           : std_logic_vector(31 downto 0);  -- output of CRC module, to output shift register
  signal crc_data_in            : std_logic;  -- input to CRC module, either data_register[52] or data_out_shift_reg[0]
  signal crc_serial_out         : std_logic;
  signal reg_select_data        : std_logic_vector(REGSELECT_SIZE-1 downto 0);  -- from data_register_i, input to internal register select register
  signal data_from_internal_reg : std_logic_vector(DATA_WIDTH downto 0);  -- data from internal reg. MUX to output shift register

  --Statemachine states
  signal module_state, module_next_state : std_logic_vector(3 downto 0);

  signal not_dbg_rst : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module body
  --

  -- Combinatorial assignments
  module_cmd      <= not data_register(DATAREG_LEN-1);
  operation_in    <= data_register(DATAREG_LEN-2 downto DATAREG_LEN-5);
  address_data_in <= data_register(DATAREG_LEN-6 downto DATAREG_LEN-ADDR_WIDTH-5);
  count_data_in   <= data_register(DATAREG_LEN-6-ADDR_WIDTH downto DATAREG_LEN-ADDR_WIDTH-21);

  data_to_biu(DATA_WIDTH-1)          <= dbg_tdi;
  data_to_biu(DATA_WIDTH-2 downto 0) <= data_register(DATAREG_LEN-1 downto DATAREG_LEN-DATA_WIDTH+1);

  reg_select_data <= data_register(DATAREG_LEN-6 downto DATAREG_LEN-REGSELECT_SIZE-5);

  -- Operation decoder

  -- These are only used before the operation is latched, so decode them from operation_in
  intreg_instruction <= to_stdlogic(operation_in = IREG_WR) or
                        to_stdlogic(operation_in = IREG_SEL);
  intreg_write <= to_stdlogic(operation_in = IREG_WR);

  burst_write <= to_stdlogic(operation_in = BWRITE8) or
                 to_stdlogic(operation_in = BWRITE16) or
                 to_stdlogic(operation_in = BWRITE32) or
                 to_stdlogic(operation_in = BWRITE64);

  burst_read <= to_stdlogic(operation_in = BREAD8) or
                to_stdlogic(operation_in = BREAD16) or
                to_stdlogic(operation_in = BREAD32) or
                to_stdlogic(operation_in = BREAD64);

  -- This is decoded from the registered operation
  processing_0 : process (dbg_clk)
  begin
    if (rising_edge(dbg_clk)) then
      if (op_reg_en = '1') then
        case ((operation_in)) is
          when BWRITE8 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(7, 6));
            word_size_bytes <= X"1";
            rd_op           <= '0';
          when BWRITE16 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(15, 6));
            word_size_bytes <= X"2";
            rd_op           <= '0';
          when BWRITE32 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(31, 6));
            word_size_bytes <= X"4";
            rd_op           <= '0';
          when BWRITE64 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(63, 6));
            word_size_bytes <= X"8";
            rd_op           <= '0';
          when BREAD8 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(7, 6));
            word_size_bytes <= X"1";
            rd_op           <= '1';
          when BREAD16 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(15, 6));
            word_size_bytes <= X"2";
            rd_op           <= '1';
          when BREAD32 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(31, 6));
            word_size_bytes <= X"4";
            rd_op           <= '1';
          when BREAD64 =>
            -- Bits is actually bits-1, to make the FSM easier
            word_size_bits  <= std_logic_vector(to_unsigned(63, 6));
            word_size_bytes <= X"8";
            rd_op           <= '1';
          when others =>
            word_size_bits  <= "XXXXXX";
            word_size_bytes <= "XXXX";
            rd_op           <= 'X';
        end case;
      end if;
    end if;
  end process;

  -- Module-internal register select register (no, that's not redundant.)
  -- Also internal register output MUX
  processing_1 : process (dbg_clk, dbg_rst)
  begin
    if (dbg_rst = '1') then
      internal_register_select <= (others => '0');
    elsif (rising_edge(dbg_clk)) then
      if (regsel_ld_en = '1') then
        internal_register_select <= reg_select_data;
      end if;
    end if;
  end process;

  -- This is completely unnecessary here, since the WB module has only 1 internal register
  -- However, to make the module expandable, it is included anyway.
  processing_2 : process (internal_register_select)
  begin
    case (internal_register_select) is
      when "00" =>
        data_from_internal_reg <= internal_reg_error;
      when others =>
        data_from_internal_reg <= internal_reg_error;
    end case;
  end process;

  -- Module-internal registers
  -- These have generic read/write/select code, but
  -- individual registers may have special behavior, defined here.

  -- This is the bus error register, which traps WB errors
  -- We latch every new BIU address in the upper 32 bits, so we always have the address for the transaction which
  -- generated the error (the address counter might increment, esp. for writes)
  -- We stop latching addresses when the error bit (bit 0) is set. Keep the error bit set until it is 
  -- manually cleared by a module internal register write.
  -- Note we use reg_select_data straight from data_register_i, rather than the latched version - 
  -- otherwise, we would write the previously selected register.
  processing_3 : process (dbg_clk, dbg_rst)
  begin
    if (dbg_rst = '1') then
      internal_reg_error <= X"0";
    elsif (rising_edge(dbg_clk)) then
      if ((intreg_ld_en = '1') and (reg_select_data = INTREG_ERROR)) then  -- do load from data input register
        if (data_register(46) = '1') then  -- if write data is 1, reset the error bit  TODO:fix 46
          internal_reg_error(0) <= '0';
        end if;
      elsif (error_reg_en = '1' and internal_reg_error(0) = '0') then
        if (biu_err = '1' or biu_rdy = '0') then
          internal_reg_error(0) <= '1';
        elsif (biu_strobe = '1') then
          internal_reg_error(DATA_WIDTH downto 1) <= address_counter;
        end if;
      elsif (biu_strobe = '1' and internal_reg_error(0) = '0') then
        internal_reg_error(DATA_WIDTH downto 1) <= address_counter;  -- When no error, latch this whether error_reg_en or not
      end if;
    end if;
  end process;

  -- Address counter

  -- Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  -- negedge, per the JTAG spec. But that makes things difficult when incrementing.
  processing_4 : process (dbg_clk, dbg_rst)  -- JTAG spec specifies latch on negative edge in UPDATE_DR state
  begin
    if (dbg_rst = '1') then
      address_counter <= X"0";
    elsif (rising_edge(dbg_clk)) then
      if (addr_ct_en = '1') then
        if (addr_sel = '1') then
          address_counter <= std_logic_vector(unsigned(address_counter)+unsigned(word_size_bytes));
        else
          address_counter <= address_data_in;
        end if;
      end if;
    end if;
  end process;

  -- Bit counter
  processing_5 : process (dbg_clk, dbg_rst)
  begin
    if (dbg_rst = '1') then
      bit_count <= (others => '0');
    elsif (rising_edge(dbg_clk)) then
      if (bit_ct_rst = '1') then
        bit_count <= (others => '0');
      elsif (bit_ct_en = '1') then
        bit_count <= std_logic_vector(unsigned(bit_count)+X"1");
      end if;
    end if;
  end process;

  bit_count_max <= to_stdlogic(bit_count = word_size_bits);
  bit_count_32  <= to_stdlogic(bit_count = std_logic_vector(to_unsigned(32, 6)));

  -- Word counter
  decremented_word_count <= std_logic_vector(unsigned(word_count)-X"1");

  -- Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  -- negedge, per the JTAG spec. But that makes things difficult when incrementing.
  processing_6 : process (dbg_clk, dbg_rst)  -- JTAG spec specifies latch on negative edge in UPDATE_DR state
  begin
    if (dbg_rst = '1') then
      word_count <= X"0000";
    elsif (rising_edge(dbg_clk)) then
      if (word_ct_en = '1') then
        if (word_ct_sel = '1') then
          word_count <= decremented_word_count;
        else
          word_count <= count_data_in;
        end if;
      end if;
    end if;
  end process;

  word_count_zero <= reduce_nor(word_count);

  -- Output register and TDO output MUX
  processing_7 : process (dbg_clk, dbg_rst)
  begin
    if (dbg_rst = '1') then
      data_out_shift_reg <= X"0";
    elsif (rising_edge(dbg_clk)) then
      if (out_reg_ld_en = '1') then
        if (out_reg_data_sel = '1') then
          data_out_shift_reg <= data_from_internal_reg;
        else 
          data_out_shift_reg <= ('0' & biu_do);
        end if;
      elsif (out_reg_shift_en = '1') then
        data_out_shift_reg <= ('0' & data_out_shift_reg(DATA_WIDTH downto 1));
      end if;
    end if;
  end process;

  processing_8 : process (tdo_output_sel)
  begin
    case (tdo_output_sel) is
      when X"0" =>
        dbg_tdo <= biu_rdy;
      when X"1" =>
        dbg_tdo <= data_out_shift_reg(0);
      when X"2" =>
        dbg_tdo <= crc_match;
      when others =>
        dbg_tdo <= crc_serial_out;
    end case;
  end process;

  -- Bus Interface Unit
  -- It is assumed that the BIU has internal registers, and will
  -- latch address, operation, and write data on rising clock edge 
  -- when strobe is asserted
  biu_clk       <= dbg_clk;
  biu_rst       <= dbg_rst or biu_clr_err;
  biu_di        <= data_to_biu;
  biu_addr      <= address_counter;
  biu_strb      <= biu_strobe;
  biu_rw        <= rd_op;
  biu_word_size <= word_size_bytes;

  -- CRC module

  crc_data_in <= dbg_tdi
                 when crc_in_sel = '1' else data_out_shift_reg(0);  -- MUX, write or read data

  wb_crc_i : mpsoc_dbg_crc32
    port map (
      rstn       => not_dbg_rst,
      clk        => dbg_clk,
      data       => crc_data_in,
      enable     => crc_en,
      shift      => crc_shift_en,
      clr        => crc_clr,
      crc_out    => crc_data_out,
      serial_out => crc_serial_out
      );

  not_dbg_rst <= not dbg_rst;
  crc_match   <= to_stdlogic(data_register(DATAREG_LEN-1-32 downto DATAREG_LEN-1) = crc_data_out);

  -- Control FSM

  -- sequential part of the FSM
  processing_9 : process (dbg_clk, dbg_rst)
  begin
    if (dbg_rst = '1') then
      module_state <= STATE_IDLE;
    elsif (rising_edge(dbg_clk)) then
      module_state <= module_next_state;
    end if;
  end process;

  -- Determination of next state; purely combinatorial
  processing_10 : process (module_state)
  begin
    case (module_state) is
      when STATE_IDLE =>
        if (module_cmd = '1' and module_select = '1' and update_dr_i = '1' and burst_read = '1') then
          module_next_state <= STATE_RBEGIN;
        elsif (module_cmd = '1' and module_select = '1' and update_dr_i = '1' and burst_write = '1') then
          module_next_state <= STATE_WREADY;
        else
          module_next_state <= STATE_IDLE;
        end if;
      when STATE_RBEGIN =>
        -- set up a burst of size 0, illegal.
        if (word_count_zero = '1') then
          module_next_state <= STATE_IDLE;
        else
          module_next_state <= STATE_RREADY;
        end if;
      when STATE_RREADY =>
        if (module_select = '1' and capture_dr_i = '1') then
          module_next_state <= STATE_RSTATUS;
        else
          module_next_state <= STATE_RREADY;
        end if;
      when STATE_RSTATUS =>
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (biu_rdy = '1') then
          module_next_state <= STATE_RBURST;
        else
          module_next_state <= STATE_RSTATUS;
        end if;
      when STATE_RBURST =>
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (bit_count_max = '1' and word_count_zero = '1') then
          module_next_state <= STATE_RCRC;
        else
          module_next_state <= STATE_RBURST;
        end if;
      when STATE_RCRC =>
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        else  -- This doubles as the 'recovery' state, so stay here until update_dr_i.
          module_next_state <= STATE_RCRC;
        end if;
      when STATE_WREADY =>
        if (word_count_zero = '1') then
          module_next_state <= STATE_IDLE;
        elsif (module_select = '1' and capture_dr_i = '1') then
          module_next_state <= STATE_WWAIT;
        else
          module_next_state <= STATE_WREADY;
        end if;
      when STATE_WWAIT =>
        -- client terminated early
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (module_select = '1' and data_register(DATAREG_LEN-1) = '1') then  -- Got a start bit
          module_next_state <= STATE_WBURST;
        else
          module_next_state <= STATE_WWAIT;
        end if;
      when STATE_WBURST =>
        -- client terminated early
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (bit_count_max = '1') then
          if (word_count_zero = '1') then
            module_next_state <= STATE_WCRC;
          else
            module_next_state <= STATE_WBURST;
          end if;
        else
          module_next_state <= STATE_WBURST;
        end if;
      when STATE_WSTATUS =>
        -- client terminated early    
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (word_count_zero = '1') then
          module_next_state <= STATE_WCRC;
        else  -- can't wait until bus ready if multiple devices in chain...
          -- Would have to read postfix_bits, then send another start bit and push it through
          -- prefix_bits...potentially very inefficient.
          module_next_state <= STATE_WBURST;
        end if;
      when STATE_WCRC =>
        -- client terminated early
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (bit_count_32 = '1') then
          module_next_state <= STATE_WMATCH;
        else
          module_next_state <= STATE_WCRC;
        end if;
      when STATE_WMATCH =>
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        else  -- This doubles as our recovery state, stay here until update_dr_i
          module_next_state <= STATE_WMATCH;
        end if;
      when others =>
        -- shouldn't actually happen...
        module_next_state <= STATE_IDLE;
    end case;
  end process;

  -- Outputs of state machine, pure combinatorial
  processing_11 : process (module_state)
  begin
    -- Default everything to 0, keeps the case statement simple
    addr_sel         <= '1';  -- Selects data for address_counter. 0 = data_register_i, 1 = incremented address count
    addr_ct_en       <= '0';  -- Enable signal for address counter register
    op_reg_en        <= '0';  -- Enable signal for 'operation' register
    bit_ct_en        <= '0';            -- enable bit counter
    bit_ct_rst       <= '0';            -- reset (zero) bit count register
    word_ct_sel      <= '1';  -- Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
    word_ct_en       <= '0';            -- Enable byte counter register
    out_reg_ld_en    <= '0';  -- Enable parallel load of data_out_shift_reg
    out_reg_shift_en <= '0';            -- Enable shift of data_out_shift_reg
    tdo_output_sel   <= X"1";  -- 1 = data reg, 0 = biu_rdy, 2 = crc_match, 3 = CRC data
    biu_strobe       <= '0';
    crc_clr          <= '0';
    crc_en           <= '0';  -- add the input bit to the CRC calculation
    crc_in_sel       <= '0';            -- 0 = tdo, 1 = tdi
    crc_shift_en     <= '0';
    out_reg_data_sel <= '1';  -- 0 = BIU data, 1 = internal register data
    regsel_ld_en     <= '0';
    intreg_ld_en     <= '0';
    error_reg_en     <= '0';
    biu_clr_err      <= '0';  -- Set this to reset the BIU, clearing the biu_err bit
    inhibit          <= '0';  -- Don't disable the top-level module in the default case

    case (module_state) is
      when STATE_IDLE =>
        addr_sel    <= '0';
        word_ct_sel <= '0';
        -- Operations for internal registers - stay in idle state
        if (module_select = '1' and shift_dr_i = '1') then     -- For module regs
          out_reg_shift_en <= '1';
        end if;
        if (module_select = '1' and capture_dr_i = '1') then
          out_reg_data_sel <= '1';      -- select internal register data
          out_reg_ld_en    <= '1';      -- For module regs
        end if;
        if (module_select = '1' and module_cmd = '1' and update_dr_i = '1') then
          if (intreg_instruction = '1') then  -- For module regs
            regsel_ld_en <= '1';
          end if;
          if (intreg_write = '1') then        -- For module regs
            intreg_ld_en <= '1';
          end if;
        end if;
        -- Burst operations
        if (module_next_state /= STATE_IDLE) then  -- Do the same to receive read or write opcode
          addr_ct_en <= '1';
          op_reg_en  <= '1';
          bit_ct_rst <= '1';
          word_ct_en <= '1';
          crc_clr    <= '1';
        end if;
      when STATE_RBEGIN =>
        -- Start a biu read transaction
        if (word_count_zero = '0') then
          biu_strobe <= '1';
          addr_sel   <= '1';
          addr_ct_en <= '1';
        end if;
      when STATE_RREADY =>
        -- Just a wait state
        null;
      when STATE_RSTATUS =>
        tdo_output_sel <= X"0";
        inhibit        <= '1';          -- in case of early termination
        if (module_next_state = STATE_RBURST) then
          error_reg_en     <= '1';      -- Check the wb_error bit
          out_reg_data_sel <= '0';      -- select BIU data
          out_reg_ld_en    <= '1';
          bit_ct_rst       <= '1';
          word_ct_sel      <= '1';
          word_ct_en       <= '1';
          if ((decremented_word_count /= X"0000") and (word_count_zero = '0')) then  -- Start a biu read transaction
            biu_strobe <= '1';
            addr_sel   <= '1';
            addr_ct_en <= '1';
          end if;
        end if;
      when STATE_RBURST =>
        tdo_output_sel   <= X"1";
        out_reg_shift_en <= '1';
        bit_ct_en        <= '1';
        crc_en           <= '1';
        crc_in_sel       <= '0';  -- read data in output shift register LSB (tdo)
        inhibit          <= '1';  -- in case of early termination
        if (bit_count_max = '1') then
          error_reg_en     <= '1';  -- Check the wb_error bit
          out_reg_data_sel <= '0';  -- select BIU data
          out_reg_ld_en    <= '1';
          bit_ct_rst       <= '1';
          word_ct_sel      <= '1';
          word_ct_en       <= '1';
          if ((decremented_word_count /= X"0000") and (word_count_zero = '0')) then  -- Start a biu read transaction
            biu_strobe <= '1';
            addr_sel   <= '1';
            addr_ct_en <= '1';
          end if;
        end if;
      when STATE_RCRC =>
        -- Just shift out the data, don't bother counting, we don't move on until update_dr_i
        tdo_output_sel <= X"3";
        crc_shift_en   <= '1';
        inhibit        <= '1';
      when STATE_WREADY =>
        -- Just a wait state
        null;
      when STATE_WWAIT =>
        tdo_output_sel <= X"1";
        inhibit        <= '1';          -- in case of early termination
        if (module_next_state = STATE_WBURST) then
          biu_clr_err <= '1';  -- If error occurred on last transaction of last burst, biu_err is still set.  Clear it.
          bit_ct_en   <= '1';
          word_ct_sel <= '1';           -- Pre-decrement the byte count
          word_ct_en  <= '1';
          crc_en      <= '1';  -- CRC gets dbg_tdi, which is 1 cycle ahead of data_register_i, so we need the bit there now in the CRC
          crc_in_sel  <= '1';           -- read data from dbg_tdi
        end if;
      when STATE_WBURST =>
        bit_ct_en      <= '1';
        tdo_output_sel <= X"1";
        crc_en         <= '1';
        crc_in_sel     <= '1';          -- read data from tdi_i
        inhibit        <= '1';          -- in case of early termination
        if (bit_count_max = '1') then
          error_reg_en <= '1';          -- Check the wb_error bit
          bit_ct_rst   <= '1';          -- Zero the bit count
          -- start transaction. Can't do this here if not hispeed, biu_rdy
          -- is the status bit, and it's 0 if we start a transaction here.
          biu_strobe   <= '1';          -- Start a BIU transaction
          addr_ct_en   <= '1';          -- Increment thte address counter
          -- Also can't dec the byte count yet unless hispeed,
          -- that would skip the last word.
          word_ct_sel  <= '1';          -- Decrement the byte count
          word_ct_en   <= '1';
        end if;
      when STATE_WSTATUS =>
        -- Send the status bit to TDO
        tdo_output_sel <= X"0";
        error_reg_en   <= '1';          -- Check the wb_error bit

        -- start transaction
        biu_strobe  <= '1';             -- Start a BIU transaction
        word_ct_sel <= '1';             -- Decrement the byte count
        word_ct_en  <= '1';
        bit_ct_rst  <= '1';             -- Zero the bit count
        addr_ct_en  <= '1';             -- Increment thte address counter
        inhibit     <= '1';             -- in case of early termination
      when STATE_WCRC =>
        bit_ct_en <= '1';
        inhibit   <= '1';               -- in case of early termination
        if (module_next_state = STATE_WMATCH) then  -- This is when the 'match' bit is actually read
          tdo_output_sel <= X"2";
        end if;
      when STATE_WMATCH =>
        tdo_output_sel <= X"2";
        inhibit        <= '1';
        -- Bit of a hack here...an error on the final write won't be detected in STATE_WSTATUS like the rest, 
        -- so we assume the bus transaction is done and check it / latch it into the error register here.
        if (module_next_state = STATE_IDLE) then
          error_reg_en <= '1';
        end if;
      when others =>
        null;
    end case;
  end process;
end RTL;
