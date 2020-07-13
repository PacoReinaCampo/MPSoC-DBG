-- Converted from rtl/verilog/core/mpsoc_dbg_or1k_module.sv
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

entity mpsoc_dbg_or1k_module is
  generic (
    X                    : integer := 2;
    Y                    : integer := 2;
    Z                    : integer := 2;
    CORES_PER_TILE       : integer := 1;
    CPU_ADDR_WIDTH       : integer := 32;
    CPU_DATA_WIDTH       : integer := 32;
    DBG_OR1K_DATAREG_LEN : integer := 64
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

    data_register_i : in  std_logic_vector(DBG_OR1K_DATAREG_LEN-1 downto 0);
    module_select_i : in  std_logic;
    top_inhibit_o   : out std_logic;

    -- Interface to debug unit
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
end mpsoc_dbg_or1k_module;

architecture RTL of mpsoc_dbg_or1k_module is
  component mpsoc_dbg_or1k_status_reg
    generic (
      X : integer := 2;
      Y : integer := 2;
      Z : integer := 2;

      CORES_PER_TILE : integer := 1
      );
    port (
      tlr_i      : in  std_logic;
      tck_i      : in  std_logic;
      we_i       : in  std_logic;
      ctrl_reg_o : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

      cpu_rstn_i  : in  std_logic;
      cpu_clk_i   : in  std_logic;
      data_i      : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
      bp_i        : in  xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);
      cpu_stall_o : out xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0)
      );
  end component;

  component mpsoc_dbg_or1k_biu
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
  end component;

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

  --FSM states
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

  constant BIU_READY : std_logic_vector(1 downto 0) := "11";
  constant DATA_OUT  : std_logic_vector(1 downto 0) := "10";
  constant CRC_MATCH : std_logic_vector(1 downto 0) := "01";
  constant CRC_OUT   : std_logic_vector(1 downto 0) := "00";

  --////////////////////////////////////////////////////////////////
  --
  -- Variables
  --

  -- Registers to hold state etc.
  signal address_counter          : std_logic_vector(31 downto 0);  -- Holds address for next CPU access
  signal bit_count                : std_logic_vector(5 downto 0);  -- How many bits have been shifted in/out
  signal word_count               : std_logic_vector(15 downto 0);  -- bytes remaining in current burst command
  signal operation                : std_logic_vector(3 downto 0);  -- holds the current command (rd/wr, word size)
  signal data_out_shift_reg       : std_logic_vector(31 downto 0);  -- parallel-load output shift register
  signal internal_register_select : std_logic_vector(1 downto 0);  -- Holds index of currently selected register

  signal internal_reg_status : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);  -- Holds CPU stall and reset status - signal is output of separate module

  -- Control signals for the various counters / registers / state machines
  signal addr_sel         : std_logic;  -- Selects data for address_counter. 0 = data_register_i, 1 = incremented address count
  signal addr_ct_en       : std_logic;  -- Enable signal for address counter register
  signal op_reg_en        : std_logic;  -- Enable signal for 'operation' register
  signal bit_ct_en        : std_logic;  -- enable bit counter
  signal bit_ct_rst       : std_logic;  -- reset (zero) bit count register
  signal word_ct_sel      : std_logic;  -- Selects data for byte counter.  0 = data_register_i, 1 = decremented byte count
  signal word_ct_en       : std_logic;  -- Enable byte counter register
  signal out_reg_ld_en    : std_logic;  -- Enable parallel load of data_out_shift_reg
  signal out_reg_shift_en : std_logic;  -- Enable shift of data_out_shift_reg
  signal out_reg_data_sel : std_logic;  -- 0 = BIU data, 1 = internal register data
  signal tdo_output_sel   : std_logic_vector(1 downto 0);  -- Selects signal to send to TDO.  0 = ready bit, 1 = output register, 2 = CRC match, 3 = CRC shift reg.
  signal biu_strobe       : std_logic;  -- Indicates that the bus unit should latch data and start a transaction
  signal crc_clr          : std_logic;  -- resets CRC module
  signal crc_en           : std_logic;  -- does 1-bit iteration in CRC module
  signal crc_in_sel       : std_logic;  -- selects incoming write data (=0) or outgoing read data (=1)as input to CRC module
  signal crc_shift_en     : std_logic;  -- CRC reg is also it's own output shift register; this enables a shift
  signal regsel_ld_en     : std_logic;  -- Reg. select register load enable
  signal intreg_ld_en     : std_logic;  -- load enable for internal registers
  signal cpusel_ld_en     : std_logic;


  -- Status signals
  signal word_count_zero    : std_logic;  -- true when byte counter is zero
  signal bit_count_max      : std_logic;  -- true when bit counter is equal to current word size
  signal module_cmd         : std_logic;  -- inverse of MSB of data_register_i. 1 means current cmd not for top level (but is for us)
  signal biu_ready_s        : std_logic;  -- indicates that the BIU has finished the last command
  signal burst_instruction  : std_logic;  -- True when the input_data_i reg has a valid burst instruction for this module
  signal intreg_instruction : std_logic;  -- True when the input_data_i reg has a valid internal register instruction
  signal intreg_write       : std_logic;  -- True when the input_data_i reg has an internal register write op
  signal rd_op              : std_logic;  -- True when operation in the opcode reg is a read, false when a write
  signal crc_match_s        : std_logic;  -- indicates whether data_register_i matches computed CRC
  signal bit_count_32       : std_logic;  -- true when bit count register == 32, for CRC after burst writes

  -- Intermediate signals
  signal word_size_bits         : std_logic_vector(5 downto 0);  -- 8,16, or 32.  Decoded from 'operation'
  signal address_increment      : std_logic_vector(2 downto 0);  -- How much to add to the address counter each iteration
  signal data_to_addr_counter   : std_logic_vector(31 downto 0);  -- output of the mux in front of the address counter inputs
  signal data_to_word_counter   : std_logic_vector(15 downto 0);  -- output of the mux in front of the byte counter input
  signal decremented_word_count : std_logic_vector(15 downto 0);
  signal address_data_in        : std_logic_vector(31 downto 0);  -- from data_register_i
  signal count_data_in          : std_logic_vector(15 downto 0);  -- from data_register_i
  signal operation_in           : std_logic_vector(3 downto 0);  -- from data_register_i
  signal data_to_biu            : std_logic_vector(31 downto 0);  -- from data_register_i
  signal data_from_biu          : std_logic_vector(31 downto 0);  -- to data_out_shift_register
  signal crc_data_out           : std_logic_vector(31 downto 0);  -- output of CRC module, to output shift register
  signal crc_data_in            : std_logic;  -- input to CRC module, either data_register_i[52] or data_out_shift_reg[0]
  signal crc_serial_out         : std_logic;
  signal reg_select_data        : std_logic_vector(DBG_OR1K_REGSELECT_LEN-1 downto 0);  -- from data_register_i, input to internal register select register
  signal out_reg_data           : std_logic_vector(31 downto 0);  -- parallel input to the output shift register
  signal data_from_internal_reg : std_logic_vector(31 downto 0);  -- data from internal reg. MUX to output shift register
  signal status_reg_wr          : std_logic;

  signal cpu_select    : std_logic_vector(3 downto 0);
  signal cpu_select_in : std_logic_vector(3 downto 0);

  signal status_reg_data : xyz_std_logic_vector(X-1 downto 0, Y-1 downto 0, Z-1 downto 0)(CORES_PER_TILE-1 downto 0);

  --FSM states
  signal module_state, module_next_state : std_logic_vector(3 downto 0);

  signal not_tlr_i : std_logic;

begin
  --////////////////////////////////////////////////////////////////
  --
  -- Module Body
  --

  -- Combinatorial assignments
  module_cmd      <= not data_register_i(DBG_OR1K_DATAREG_LEN-1);
  operation_in    <= data_register_i(DBG_OR1K_DATAREG_LEN-2 downto DBG_OR1K_DATAREG_LEN-5);
  cpu_select_in   <= data_register_i(DBG_OR1K_DATAREG_LEN-6 downto DBG_OR1K_DATAREG_LEN-9);
  address_data_in <= data_register_i(DBG_OR1K_DATAREG_LEN-10 downto DBG_OR1K_DATAREG_LEN-41);
  count_data_in   <= data_register_i(DBG_OR1K_DATAREG_LEN-42 downto DBG_OR1K_DATAREG_LEN-57);

  data_to_biu(31)          <= tdi_i;
  data_to_biu(30 downto 1) <= data_register_i(DBG_OR1K_DATAREG_LEN-1 downto DBG_OR1K_DATAREG_LEN-30);

  reg_select_data <= data_register_i(DBG_OR1K_DATAREG_LEN-6 downto DBG_OR1K_DATAREG_LEN-DBG_OR1K_REGSELECT_LEN-5);

  --data is sent first, then module_cmd, operation, cpu_select
  generating_0 : for i in 0 to X - 1 generate
    generating_1 : for j in 0 to Y - 1 generate
      generating_2 : for k in 0 to Z - 1 generate
        generating_3 : for t in 0 to CORES_PER_TILE - 1 generate
          status_reg_data(i, j, k)(t) <= data_register_i((i+1)*(j+1)*(k+1)*(t+1)-1);
        end generate;
      end generate;
    end generate;
  end generate;

  --//////////////////////////////////////////////
  -- Operation decoder

  -- These are only used before the operation is latched, so decode them from operation_in
  burst_instruction  <= to_stdlogic(operation_in = DBG_OR1K_CMD_BWRITE32) or to_stdlogic(operation_in = DBG_OR1K_CMD_BREAD32);
  intreg_instruction <= to_stdlogic(operation_in = DBG_OR1K_CMD_IREG_WR) or to_stdlogic(operation_in = DBG_OR1K_CMD_IREG_SEL);
  intreg_write       <= to_stdlogic(operation_in = DBG_OR1K_CMD_IREG_WR);

  -- These are constant, the CPU module only does 32-bit accesses
  word_size_bits    <= std_logic_vector(to_unsigned(31, 6));  -- Bits is actually bits-1, to make the FSM easier
  address_increment <= "001";  -- This is only used to increment the address.  SPRs are word-addressed.

  -- This is the only thing that actually needs to be saved and 'decoded' from the latched opcode
  -- It goes to the BIU each time a transaction is started.
  rd_op <= operation(2);

  -- Module-internal register select register (no, that's not redundant.)
  -- Also internal register output MUX
  processing_0 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      internal_register_select <= (others => '0');
    elsif (rising_edge(tck_i)) then
      if (regsel_ld_en = '1') then
        internal_register_select <= reg_select_data;
      end if;
    end if;
  end process;

  --//////////////////////////////////////////////
  -- CPU select register
  --
  processing_1 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      cpu_select <= X"0";
    elsif (rising_edge(tck_i)) then
      if (cpusel_ld_en = '1') then
        cpu_select <= cpu_select_in;
      end if;
    end if;
  end process;

  -- This is completely unnecessary here, since the module has only 1 internal
  -- register.  However, to make the module expandable, it is included anyway.
  processing_2 : process (internal_register_select)
  begin
    case (internal_register_select) is
      when "00" =>
        for i in 0 to X - 1 loop
          for j in 0 to Y - 1 loop
            for k in 0 to Z - 1 loop
              for t in 0 to CORES_PER_TILE - 1 loop
                data_from_internal_reg((i+1)*(j+1)*(k+1)*(t+1)-1) <= internal_reg_status(i, j, k)(t);
              end loop;
            end loop;
          end loop;
        end loop;
      when others =>
        for i in 0 to X - 1 loop
          for j in 0 to Y - 1 loop
            for k in 0 to Z - 1 loop
              for t in 0 to CORES_PER_TILE - 1 loop
                data_from_internal_reg((i+1)*(j+1)*(k+1)*(t+1)-1) <= internal_reg_status(i, j, k)(t);
              end loop;
            end loop;
          end loop;
        end loop;
    end case;
  end process;

  -- Module-internal registers
  -- These have generic read/write/select code, but
  -- individual registers may have special behavior, defined here.

  -- This is the status register, which holds the reset and stall states.
  status_reg_wr <= (intreg_ld_en and to_stdlogic(reg_select_data = DBG_OR1K_INTREG_STATUS));

  or1k_statusreg_i : mpsoc_dbg_or1k_status_reg
    generic map (
      X              => X,
      Y              => Y,
      Z              => Z,
      CORES_PER_TILE => CORES_PER_TILE
      )
    port map (
      tck_i       => tck_i,
      tlr_i       => tlr_i,
      data_i      => status_reg_data,
      we_i        => status_reg_wr,
      bp_i        => cpu_bp_i,
      cpu_clk_i   => cpu_clk_i,
      cpu_rstn_i  => cpu_rstn_i,
      ctrl_reg_o  => internal_reg_status,
      cpu_stall_o => cpu_stall_o
      );

  -- Address counter
  data_to_addr_counter <= std_logic_vector(unsigned(address_counter)+unsigned(address_increment))
                          when addr_sel = '1' else address_data_in;

  -- Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  -- negedge, per the JTAG spec. But that makes things difficult when incrementing.
  processing_3 : process (tck_i, tlr_i)  -- JTAG spec specifies latch on negative edge in UPDATE_DR state
  begin
    if (tlr_i = '1') then
      address_counter <= (others => '0');
    elsif (rising_edge(tck_i)) then
      if (addr_ct_en = '1') then
        address_counter <= data_to_addr_counter;
      end if;
    end if;
  end process;

  -- Opcode latch
  processing_4 : process (tck_i, tlr_i)  -- JTAG spec specifies latch on negative edge in UPDATE_DR state
  begin
    if (tlr_i = '1') then
      operation <= X"0";
    elsif (rising_edge(tck_i)) then
      if (op_reg_en = '1') then
        operation <= operation_in;
      end if;
    end if;
  end process;

  -- Bit counter
  processing_5 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      bit_count <= "000000";
    elsif (rising_edge(tck_i)) then
      if (bit_ct_rst = '1') then
        bit_count <= "000000";
      elsif (bit_ct_en = '1') then
        bit_count <= std_logic_vector(unsigned(bit_count)+"000001");
      end if;
    end if;
  end process;

  bit_count_max <= to_stdlogic(bit_count = word_size_bits);
  bit_count_32  <= to_stdlogic(unsigned(bit_count) = to_unsigned(32, 6));

  -- Word counter
  data_to_word_counter <= decremented_word_count
                          when word_ct_sel = '1' else count_data_in;
  decremented_word_count <= std_logic_vector(unsigned(word_count)-X"0001");

  -- Technically, since this data (sometimes) comes from the input shift reg, we should latch on
  -- negedge, per the JTAG spec. But that makes things difficult when incrementing.
  processing_6 : process (tck_i, tlr_i)  -- JTAG spec specifies latch on negative edge in UPDATE_DR state
  begin
    if (tlr_i = '1') then
      word_count <= X"0000";
    elsif (rising_edge(tck_i)) then
      if (word_ct_en = '1') then
        word_count <= data_to_word_counter;
      end if;
    end if;
  end process;

  word_count_zero <= reduce_nor(word_count);

  -- Output register and TDO output MUX
  out_reg_data <= data_from_internal_reg
                  when out_reg_data_sel = '1' else data_from_biu;

  processing_7 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      data_out_shift_reg <= X"00000000";
    elsif (rising_edge(tck_i)) then
      if (out_reg_ld_en = '1') then
        data_out_shift_reg <= out_reg_data;
      elsif (out_reg_shift_en = '1') then
        data_out_shift_reg <= ('0' & data_out_shift_reg(31 downto 1));
      end if;
    end if;
  end process;

  processing_8 : process (tdo_output_sel)
  begin
    case (tdo_output_sel) is
      when BIU_READY =>
        module_tdo_o <= biu_ready_s;
      when DATA_OUT =>
        module_tdo_o <= data_out_shift_reg(0);
      when CRC_MATCH =>
        module_tdo_o <= crc_match_s;
      when others =>
        module_tdo_o <= crc_serial_out;
    end case;
  end process;

  -- Bus Interface Unit (to OR1K SPR bus)
  -- It is assumed that the BIU has internal registers, and will
  -- latch address, operation, and write data on rising clock edge
  -- when strobe is asserted
  or1k_biu_i : mpsoc_dbg_or1k_biu
    generic map (
      X              => X,
      Y              => Y,
      Z              => Z,
      CORES_PER_TILE => CORES_PER_TILE,
      CPU_ADDR_WIDTH => CPU_ADDR_WIDTH,
      CPU_DATA_WIDTH => CPU_DATA_WIDTH
      )
    port map (
      -- Debug interface signals
      tck_i        => tck_i,
      tlr_i        => tlr_i,
      cpu_select_i => cpu_select,
      data_i       => data_to_biu,
      data_o       => data_from_biu,
      addr_i       => address_counter,
      strobe_i     => biu_strobe,
      rd_wrn_i     => rd_op,            -- If 0, then write op
      rdy_o        => biu_ready_s,
      --  This bus has no error signal

      -- OR1K SPR bus signals
      cpu_clk_i  => cpu_clk_i,
      cpu_rstn_i => cpu_rstn_i,
      cpu_addr_o => cpu_addr_o,
      cpu_data_i => cpu_data_i,
      cpu_data_o => cpu_data_o,
      cpu_stb_o  => cpu_stb_o,
      cpu_we_o   => cpu_we_o,
      cpu_ack_i  => cpu_ack_i
      );

  -- CRC module
  crc_data_in <= tdi_i
                 when crc_in_sel = '1' else data_out_shift_reg(0);  -- MUX, write or read data

  or1k_crc_i : mpsoc_dbg_crc32
    port map (
      rstn       => not_tlr_i,
      clk        => tck_i,
      data       => crc_data_in,
      enable     => crc_en,
      shift      => crc_shift_en,
      clr        => crc_clr,
      crc_out    => crc_data_out,
      serial_out => crc_serial_out
      );
  not_tlr_i <= not tlr_i;

  crc_match_s <= to_stdlogic(data_register_i(DBG_OR1K_DATAREG_LEN-1 downto DBG_OR1K_DATAREG_LEN-32) = crc_data_out);

  -- Control FSM

  -- sequential part of the FSM
  processing_9 : process (tck_i, tlr_i)
  begin
    if (tlr_i = '1') then
      module_state <= STATE_IDLE;
    elsif (rising_edge(tck_i)) then
      module_state <= module_next_state;
    end if;
  end process;

  -- Determination of next state; purely combinatorial
  processing_10 : process (module_state)
  begin
    case (module_state) is
      when STATE_IDLE =>
        if (module_cmd = '1' and module_select_i = '1' and update_dr_i = '1' and burst_instruction = '1') then
          if (operation_in(2) = '1') then
            module_next_state <= STATE_RBEGIN;
          else
            module_next_state <= STATE_WREADY;
          end if;
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
        if (module_select_i = '1' and capture_dr_i = '1') then
          module_next_state <= STATE_RSTATUS;
        else
          module_next_state <= STATE_RREADY;
        end if;
      when STATE_RSTATUS =>
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (biu_ready_s = '1') then
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
        elsif (module_select_i = '1' and capture_dr_i = '1') then
          module_next_state <= STATE_WWAIT;
        else
          module_next_state <= STATE_WREADY;
        end if;
      when STATE_WWAIT =>
        -- client terminated early
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (module_select_i = '1' and data_register_i(DBG_OR1K_DATAREG_LEN-1) = '1') then  -- Got a start bit
          module_next_state <= STATE_WBURST;
        else
          module_next_state <= STATE_WWAIT;
        end if;
      when STATE_WBURST =>
        -- client terminated early
        if (update_dr_i = '1') then
          module_next_state <= STATE_IDLE;
        elsif (bit_count_max = '1' and word_count_zero = '1') then
          module_next_state <= STATE_WCRC;
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
    tdo_output_sel   <= DATA_OUT;  -- 1 = data reg, 0 = biu_ready, 2 = crc_match, 3 = CRC data
    biu_strobe       <= '0';
    crc_clr          <= '0';
    crc_en           <= '0';  -- add the input bit to the CRC calculation
    crc_in_sel       <= '0';            -- 0 = tdo, 1 = tdi
    crc_shift_en     <= '0';
    out_reg_data_sel <= '1';  -- 0 = BIU data, 1 = internal register data
    regsel_ld_en     <= '0';
    cpusel_ld_en     <= '0';
    intreg_ld_en     <= '0';
    top_inhibit_o    <= '0';  -- Don't disable the top-level module in the default case
    case (module_state) is
      when STATE_IDLE =>
        addr_sel    <= '0';
        word_ct_sel <= '0';
        -- Operations for internal registers - stay in idle state
        if (module_select_i = '1' and shift_dr_i = '1') then   -- For module regs
          out_reg_shift_en <= '1';
        end if;
        if (module_select_i = '1' and capture_dr_i = '1') then
          out_reg_data_sel <= '1';      -- select internal register data
          out_reg_ld_en    <= '1';      -- For module regs
        end if;
        if (module_select_i = '1' and module_cmd = '1' and update_dr_i = '1') then
          if (intreg_instruction = '1') then  -- For module regs
            regsel_ld_en <= '1';
          end if;
          if (intreg_write = '1') then        -- For module regs
            intreg_ld_en <= '1';
          end if;
          if (burst_instruction = '1') then
            cpusel_ld_en <= '1';
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
        if (word_count_zero = '0') then
          -- Start a biu read transaction
          biu_strobe <= '1';
          addr_sel   <= '1';
          addr_ct_en <= '1';
        end if;
      when STATE_RREADY =>
        -- Just a wait state
        null;
      when STATE_RSTATUS =>
        tdo_output_sel <= BIU_READY;
        top_inhibit_o  <= '1';          -- in case of early termination
        if (module_next_state = STATE_RBURST) then
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
        tdo_output_sel   <= DATA_OUT;
        out_reg_shift_en <= '1';
        bit_ct_en        <= '1';
        crc_en           <= '1';
        crc_in_sel       <= '0';  -- read data in output shift register LSB (tdo)
        top_inhibit_o    <= '1';        -- in case of early termination
        if (bit_count_max = '1') then
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
      when STATE_RCRC =>
        -- Just shift out the data, don't bother counting, we don't move on until update_dr_i
        tdo_output_sel <= CRC_OUT;
        crc_shift_en   <= '1';
        top_inhibit_o  <= '1';
      when STATE_WREADY =>
        -- Just a wait state
        null;
      when STATE_WWAIT =>
        tdo_output_sel <= DATA_OUT;
        top_inhibit_o  <= '1';          -- in case of early termination
        if (module_next_state = STATE_WBURST) then
          bit_ct_en   <= '1';
          word_ct_sel <= '1';           -- Pre-decrement the byte count
          word_ct_en  <= '1';
          crc_en      <= '1';  -- CRC gets tdi_i, which is 1 cycle ahead of data_register_i, so we need the bit there now in the CRC
          crc_in_sel  <= '1';           -- read data from tdi_i
        end if;
      when STATE_WBURST =>
        bit_ct_en      <= '1';
        tdo_output_sel <= DATA_OUT;
        crc_en         <= '1';
        crc_in_sel     <= '1';          -- read data from tdi_i
        top_inhibit_o  <= '1';          -- in case of early termination
        -- It would be better to do this in STATE_WSTATUS, but we don't use that state
        -- if mpsoc_dbg_USE_HISPEED is defined.
        if (bit_count_max = '1') then
          bit_ct_rst  <= '1';           -- Zero the bit count
          -- start transaction. Can't do this here if not hispeed, biu_ready
          -- is the status bit, and it's 0 if we start a transaction here.
          biu_strobe  <= '1';           -- Start a BIU transaction
          addr_ct_en  <= '1';           -- Increment thte address counter
          -- Also can't dec the byte count yet unless hispeed,
          -- that would skip the last word.
          word_ct_sel <= '1';           -- Decrement the byte count
          word_ct_en  <= '1';
        end if;
      when STATE_WSTATUS =>
        -- Send the status bit to TDO
        tdo_output_sel <= BIU_READY;
        -- start transaction
        biu_strobe     <= '1';          -- Start a BIU transaction
        word_ct_sel    <= '1';          -- Decrement the byte count
        word_ct_en     <= '1';
        bit_ct_rst     <= '1';          -- Zero the bit count
        addr_ct_en     <= '1';          -- Increment thte address counter
        top_inhibit_o  <= '1';          -- in case of early termination
      when STATE_WCRC =>
        bit_ct_en     <= '1';
        top_inhibit_o <= '1';           -- in case of early termination
        if (module_next_state = STATE_WMATCH) then  -- This is when the 'match' bit is actually read
          tdo_output_sel <= CRC_MATCH;
        end if;
      when STATE_WMATCH =>
        tdo_output_sel <= CRC_MATCH;
        top_inhibit_o  <= '1';          -- in case of early termination
      when others =>
        null;
    end case;
  end process;
end RTL;
