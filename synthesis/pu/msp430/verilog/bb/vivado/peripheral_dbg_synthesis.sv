////////////////////////////////////////////////////////////////////////////////
//                                            __ _      _     _               //
//                                           / _(_)    | |   | |              //
//                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
//               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
//              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
//               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
//                  | |                                                       //
//                  |_|                                                       //
//                                                                            //
//                                                                            //
//              MSP430 CPU                                                    //
//              Processing Unit                                               //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/* Copyright (c) 2015-2016 by the author(s)
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the authors nor the names of its contributors
 *       may be used to endorse or promote products derived from this software
 *       without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
 * OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE
 *
 * =============================================================================
 * Author(s):
 *   Olivier Girard <olgirard@gmail.com>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

`ifdef OMSP_NO_INCLUDE
`else
`include "peripheral_dbg_pu_msp430_defines.sv"
`endif

module peripheral_dbg_synthesis (
  // OUTPUTs
  output        dbg_cpu_reset,    // Reset CPU from debug interface
  output        dbg_freeze,       // Freeze peripherals
  output [15:0] dbg_mem_addr,     // Debug address for rd/wr access

  // INPUTs
  input        cpu_en_s,           // Enable CPU code execution (synchronous)
  input [31:0] cpu_id,             // CPU ID
  input [ 7:0] cpu_nr_inst,        // Current oMSP instance number
  input [ 7:0] cpu_nr_total,       // Total number of oMSP instances-1
  input        dbg_clk,            // Debug unit clock
  input        dbg_en_s,           // Debug interface enable (synchronous)
  input        dbg_halt_st,        // Halt/Run status from CPU
  input        dbg_i2c_scl,        // Debug interface: I2C SCL
  input        dbg_rst,            // Debug unit reset
  input        dbg_uart_rxd,       // Debug interface: UART RXD (asynchronous)
  input        decode_noirq,       // Frontend decode instruction
  input        eu_mb_en,           // Execution-Unit Memory bus enable
  input [ 1:0] eu_mb_wr            // Execution-Unit Memory bus write transfer
);

  //////////////////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  // OUTPUTs
  logic        dbg_halt_cmd;     // Halt CPU command
  logic        dbg_i2c_sda_out;  // Debug interface: I2C SDA OUT
  logic [15:0] dbg_mem_dout;     // Debug unit data output
  logic        dbg_mem_en;       // Debug unit memory enable
  logic [ 1:0] dbg_mem_wr;       // Debug unit memory write
  logic        dbg_reg_wr;       // Debug unit CPU register write
  logic        dbg_uart_txd;     // Debug interface: UART TXD

  // INPUTs
  logic [ 6:0] dbg_i2c_addr;       // Debug interface: I2C Address
  logic [ 6:0] dbg_i2c_broadcast;  // Debug interface: I2C Broadcast Address (for multicore systems)
  logic        dbg_i2c_sda_in;     // Debug interface: I2C SDA IN
  logic [15:0] dbg_mem_din;        // Debug unit Memory data input
  logic [15:0] dbg_reg_din;        // Debug unit CPU register data input
  logic [15:0] eu_mab;             // Execution-Unit Memory address bus
  logic [15:0] fe_mdb_in;          // Frontend Memory data bus input
  logic [15:0] pc;                 // Program counter
  logic        puc_pnd_set;        // PUC pending set for the serial debug interface

  //////////////////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  // DUT BB
  peripheral_dbg_pu_msp430 dbg_pu_msp430 (
    // OUTPUTs
    .dbg_cpu_reset  (dbg_cpu_reset),    // Reset CPU from debug interface
    .dbg_freeze     (dbg_freeze),       // Freeze peripherals
    .dbg_halt_cmd   (dbg_halt_cmd),     // Halt CPU command
    .dbg_i2c_sda_out(dbg_i2c_sda_out),  // Debug interface: I2C SDA OUT
    .dbg_mem_addr   (dbg_mem_addr),     // Debug address for rd/wr access
    .dbg_mem_dout   (dbg_mem_dout),     // Debug unit data output
    .dbg_mem_en     (dbg_mem_en),       // Debug unit memory enable
    .dbg_mem_wr     (dbg_mem_wr),       // Debug unit memory write
    .dbg_reg_wr     (dbg_reg_wr),       // Debug unit CPU register write
    .dbg_uart_txd   (dbg_uart_txd),     // Debug interface: UART TXD

    // INPUTs
    .cpu_en_s         (cpu_en_s),           // Enable CPU code execution (synchronous)
    .cpu_id           (cpu_id),             // CPU ID
    .cpu_nr_inst      (cpu_nr_inst),        // Current oMSP instance number
    .cpu_nr_total     (cpu_nr_total),       // Total number of oMSP instances-1
    .dbg_clk          (dbg_clk),            // Debug unit clock
    .dbg_en_s         (dbg_en_s),           // Debug interface enable (synchronous)
    .dbg_halt_st      (dbg_halt_st),        // Halt/Run status from CPU
    .dbg_i2c_addr     (dbg_i2c_addr),       // Debug interface: I2C Address
    .dbg_i2c_broadcast(dbg_i2c_broadcast),  // Debug interface: I2C Broadcast Address (for multicore systems)
    .dbg_i2c_scl      (dbg_i2c_scl),        // Debug interface: I2C SCL
    .dbg_i2c_sda_in   (dbg_i2c_sda_in),     // Debug interface: I2C SDA IN
    .dbg_mem_din      (dbg_mem_din),        // Debug unit Memory data input
    .dbg_reg_din      (dbg_reg_din),        // Debug unit CPU register data input
    .dbg_rst          (dbg_rst),            // Debug unit reset
    .dbg_uart_rxd     (dbg_uart_rxd),       // Debug interface: UART RXD (asynchronous)
    .decode_noirq     (decode_noirq),       // Frontend decode instruction
    .eu_mab           (eu_mab),             // Execution-Unit Memory address bus
    .eu_mb_en         (eu_mb_en),           // Execution-Unit Memory bus enable
    .eu_mb_wr         (eu_mb_wr),           // Execution-Unit Memory bus write transfer
    .fe_mdb_in        (fe_mdb_in),          // Frontend Memory data bus input
    .pc               (pc),                 // Program counter
    .puc_pnd_set      (puc_pnd_set)         // PUC pending set for the serial debug interface
  );
endmodule  // peripheral_dbg_synthesis

`ifdef OMSP_NO_INCLUDE
`else
`include "peripheral_dbg_pu_msp430_undefines.sv"
`endif
