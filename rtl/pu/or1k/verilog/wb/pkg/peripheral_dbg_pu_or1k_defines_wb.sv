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
//              Degub Interface                                               //
//              PU-OR1K                                                       //
//              WishBone Bus Interface                                        //
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
 *   Nathan Yawn <nathan.yawn@opencores.org>
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

// Endian-ness of the Wishbone interface.
// Default is BIG endian, to match the OR1200.
// If using a LITTLE endian CPU, e.g. an x86, un-comment this line.
//`define DBG_WB_LITTLE_ENDIAN

// These relate to the number of internal registers, and how
// many bits are required in the Reg. Select register
`define DBG_WB_REGSELECT_SIZE 1
`define DBG_WB_NUM_INTREG     1

// Register index definitions for module-internal registers
// The WB module has just 1, the error register
`define DBG_WB_INTREG_ERROR 1'b0

// Valid commands/opcodes for the wishbone debug module
// 0000  NOP
// 0001  Write burst, 8-bit access
// 0010  Write burst, 16-bit access
// 0011  Write burst, 32-bit access
// 0100  Reserved
// 0101  Read burst, 8-bit access
// 0110  Read burst, 16-bit access
// 0111  Read burst, 32-bit access
// 1000  Reserved
// 1001  Internal register select/write
// 1010 - 1100 Reserved
// 1101  Internal register select
// 1110 - 1111 Reserved

`define DBG_WB_CMD_BWRITE8  4'h1
`define DBG_WB_CMD_BWRITE16 4'h2
`define DBG_WB_CMD_BWRITE32 4'h3
`define DBG_WB_CMD_BREAD8   4'h5
`define DBG_WB_CMD_BREAD16  4'h6
`define DBG_WB_CMD_BREAD32  4'h7
`define DBG_WB_CMD_IREG_WR  4'h9
`define DBG_WB_CMD_IREG_SEL 4'hd
