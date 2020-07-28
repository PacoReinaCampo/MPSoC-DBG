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

interface dut_if;
  logic        hrst;
  logic        hclk;
  logic        hsel;
  logic [31:0] haddr;
  logic [31:0] hwdata;
  logic [31:0] hrdata;
  logic        hwrite;
  logic [ 2:0] hsize;
  logic [ 2:0] hburst;
  logic [ 3:0] hprot;
  logic [ 1:0] htrans;
  logic        hmastlock;
  logic        hreadyout;
  logic        hready;
  logic        hresp;
  
  //Master Clocking block - used for Drivers
  clocking master_cb @(posedge pclk);
    input         hsel;
    input  [31:0] haddr;
    input  [31:0] hwdata;
    output [31:0] hrdata;
    input         hwrite;
    input  [ 2:0] hsize;
    input  [ 2:0] hburst;
    input  [ 3:0] hprot;
    input  [ 1:0] htrans;
    input         hmastlock;
    output        hreadyout;
    input         hready;
    output        hresp;
  endclocking: master_cb

  //Slave Clocking Block - used for any Slave BFMs
  clocking slave_cb @(posedge pclk);
    output        hsel;
    output [31:0] haddr;
    output [31:0] hwdata;
    input  [31:0] hrdata;
    output        hwrite;
    output [ 2:0] hsize;
    output [ 2:0] hburst;
    output [ 3:0] hprot;
    output [ 1:0] htrans;
    output        hmastlock;
    input         hreadyout;
    output        hready;
    input         hresp;
  endclocking: slave_cb

  //Monitor Clocking block - For sampling by monitor components
  clocking monitor_cb @(posedge pclk);
    input        hsel;
    input [31:0] haddr;
    input [31:0] hwdata;
    input [31:0] hrdata;
    input        hwrite;
    input [ 2:0] hsize;
    input [ 2:0] hburst;
    input [ 3:0] hprot;
    input [ 1:0] htrans;
    input        hmastlock;
    input        hreadyout;
    input        hready;
    input        hresp;
  endclocking: monitor_cb

  modport master(clocking master_cb);
  modport slave(clocking slave_cb);
  modport passive(clocking monitor_cb);
endinterface

module ahb3_slave(dut_if dif);
  logic [31:0] mem [0:256];
  logic [ 1:0] ahb3_st;

  const logic [1:0] SETUP=0;
  const logic [1:0] W_ENABLE=1;
  const logic [1:0] R_ENABLE=2;
  
  always @(posedge dif.pclk or negedge dif.prst) begin
    if (dif.prst==0) begin
      ahb3_st <=0;
      dif.prdata <=0;
      dif.pready <=1;
      for(int i=0;i<256;i++) mem[i]=i;
    end
    else begin
      case (ahb3_st)
        SETUP: begin
          dif.prdata <= 0;
          if (dif.psel && !dif.penable) begin
            if (dif.pwrite) begin
              ahb3_st <= W_ENABLE;
            end
            else begin
              ahb3_st <= R_ENABLE;
              dif.prdata <= mem[dif.paddr];
            end
          end
        end
        W_ENABLE: begin
          if (dif.psel && dif.penable && dif.pwrite) begin
            mem[dif.paddr] <= dif.pwdata;
          end
          ahb3_st <= SETUP;
        end
        R_ENABLE: begin
          ahb3_st <= SETUP;
        end
      endcase
    end
  end
endmodule
