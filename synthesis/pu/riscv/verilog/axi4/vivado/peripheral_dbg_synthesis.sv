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
//              MPSoC-RISCV CPU                                               //
//              Master Slave Interface Tesbench                               //
//              AMBA3 AHB-Lite Bus Interface                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/* Copyright (c) 2018-2019 by the author(s)
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

module peripheral_dbg_testbench;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam XLEN = 64;
  localparam PLEN = 64;

  localparam SYNC_DEPTH = 3;
  localparam TECHNOLOGY = "GENERIC";

  //Memory parameters
  parameter DEPTH = 256;
  parameter MEMFILE = "";

  //////////////////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  //Common signals
  wire                       HRESETn;
  wire                       HCLK;

  //AHB3 signals
  wire                       mst_dbg_HSEL;
  wire [PLEN           -1:0] mst_dbg_HADDR;
  wire [XLEN           -1:0] mst_dbg_HWDATA;
  wire [XLEN           -1:0] mst_dbg_HRDATA;
  wire                       mst_dbg_HWRITE;
  wire [                2:0] mst_dbg_HSIZE;
  wire [                2:0] mst_dbg_HBURST;
  wire [                3:0] mst_dbg_HPROT;
  wire [                1:0] mst_dbg_HTRANS;
  wire                       mst_dbg_HMASTLOCK;
  wire                       mst_dbg_HREADY;
  wire                       mst_dbg_HREADYOUT;
  wire                       mst_dbg_HRESP;

  //////////////////////////////////////////////////////////////////
  //
  // Module Body
  //

  // DUT AHB3
  peripheral_dbg_ahb3 #(
    .MEM_SIZE         (256),
    .MEM_DEPTH        (256),
    .PLEN             (PLEN),
    .XLEN             (XLEN),
    .TECHNOLOGY       (TECHNOLOGY),
    .REGISTERED_OUTPUT("NO")
  ) dbg_ahb3 (
    .HRESETn(HRESETn),
    .HCLK   (HCLK),

    .HSEL     (mst_dbg_HSEL),
    .HADDR    (mst_dbg_HADDR),
    .HWDATA   (mst_dbg_HWDATA),
    .HRDATA   (mst_dbg_HRDATA),
    .HWRITE   (mst_dbg_HWRITE),
    .HSIZE    (mst_dbg_HSIZE),
    .HBURST   (mst_dbg_HBURST),
    .HPROT    (mst_dbg_HPROT),
    .HTRANS   (mst_dbg_HTRANS),
    .HMASTLOCK(mst_dbg_HMASTLOCK),
    .HREADYOUT(mst_dbg_HREADYOUT),
    .HREADY   (mst_dbg_HREADY),
    .HRESP    (mst_dbg_HRESP)
  );
endmodule
