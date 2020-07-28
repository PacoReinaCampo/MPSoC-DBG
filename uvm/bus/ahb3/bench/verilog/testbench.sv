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
//              MPSoC-RISCV / OR1K / MSP430 CPU                               //
//              General Purpose Input Output Bridge                           //
//              AMBA3 AHB-Lite Bus Interface                                  //
//              Universal Verification Methodology                            //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/* Copyright (c) 2020-2021 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 * Author(s):
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

//Include UVM files
`include "uvm_macros.svh"
`include "uvm_pkg.sv"
import uvm_pkg::*;

//Include common files
`include "ahb3_transaction.svh"
`include "ahb3_sequence.svh"
`include "ahb3_sequencer.svh"
`include "ahb3_driver.svh"
`include "ahb3_monitor.svh"
`include "ahb3_agent.svh"
`include "ahb3_scoreboard.svh"
`include "ahb3_subscriber.svh"
`include "ahb3_env.svh"
`include "ahb3_test.svh"

module test;
  logic        hclk;
  logic        prst;
  logic [31:0] haddr;
  logic        hsel;
  logic        hwrite;
  logic [31:0] hrdata;
  logic [31:0] hwdata;

  dut_if ahb3_if();

  ahb3_slave dut(.dif(ahb3_if));

  initial begin
    ahb3_if.hclk=0;
  end

  //Generate a clock
  always begin
    #10 ahb3_if.hclk = ~ahb3_if.hclk;
  end

  initial begin
    ahb3_if.prst=0;
    repeat (1) @(posedge ahb3_if.hclk);
    ahb3_if.prst=1;
  end

  initial begin
    uvm_config_db#(virtual dut_if)::set( null, "uvm_test_top", "vif", ahb3_if);
    run_test("ahb3_test");
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule