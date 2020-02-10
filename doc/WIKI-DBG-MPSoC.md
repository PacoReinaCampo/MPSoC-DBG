# DBG-MPSoC WIKI

A Debugger on Chip (DBG) is a Hardware-Software System used to test and debug Hardware Description Languages. The code to be examined is running on a simulator, a technique that allows great power in its ability to halt when specific conditions are encountered. When a hardware description crashes, debuggers show the position of the error in the target description.


## Instruction INPUTS/OUTPUTS AMBA3 AHB-Lite Bus

| Port         |  Size  | Direction | Description                                           |
| -------------| ------ | --------- | ----------------------------------------------------- |
| `HRESETn`    |    1   |   Input   | Asynchronous active low reset                         |
| `HCLK`       |    1   |   Input   | System clock input                                    |
|              |        |           |                                                       |
| `IHSEL`      |    1   |   Output  | Provided for AHB-Lite compatibility – tied high ('1') |
| `IHADDR`     | `PLEN` |   Output  | Instruction address                                   |
| `IHRDATA`    | `XLEN` |   Input   | Instruction read data                                 |
| `IHWDATA`    | `XLEN` |   Output  | Instruction write data                                |
| `IHWRITE`    |    1   |   Output  | Instruction write                                     |
| `IHSIZE`     |    3   |   Output  | Transfer size                                         |
| `IHBURST`    |    3   |   Output  | Transfer burst size                                   |
| `IHPROT`     |    4   |   Output  | Transfer protection level                             |
| `IHTRANS`    |    2   |   Output  | Transfer type                                         |
| `IHMASTLOCK` |    1   |   Output  | Transfer master lock                                  |
| `IHREADY`    |    1   |   Input   | Slave Ready Indicator                                 |
| `IHRESP`     |    1   |   Input   | Instruction Transfer Response                         |


## Instruction INPUTS/OUTPUTS Wishbone Bus

| Port    |  Size  | Direction | Description                     |
| --------| ------ | --------- | ------------------------------- |
| `rst`   |    1   |   Input   | Synchronous, active high        |
| `clk`   |    1   |   Input   | Master clock                    |
|         |        |           |                                 |
| `iadr`  | `PLEN` |   Input   | Lower address bits              |
| `idati` | `XLEN` |   Input   | Data towards the core           |
| `idato` | `XLEN` |   Output  | Data from the core              |
| `isel`  |    4   |   Input   | Byte select signals             |
| `iwe`   |    1   |   Input   | Write enable input              |
| `istb`  |    1   |   Input   | Strobe signal/Core select input |
| `icyc`  |    1   |   Input   | Valid bus cycle input           |
| `iack`  |    1   |   Output  | Bus cycle acknowledge output    |
| `ierr`  |    1   |   Output  | Bus cycle error output          |
| `iint`  |    1   |   Output  | Interrupt signal output         |


## Data INPUTS/OUTPUTS AMBA3 AHB-Lite Bus

| Port         |  Size  | Direction | Description                                           |
| -------------| ------ | --------- | ----------------------------------------------------- |
| `HRESETn`    |    1   |   Input   | Asynchronous active low reset                         |
| `HCLK`       |    1   |   Input   | System clock input                                    |
|              |        |           |                                                       |
| `DHSEL`      |    1   |   Output  | Provided for AHB-Lite compatibility – tied high ('1') |
| `DHADDR`     | `PLEN` |   Output  | Data address                                          |
| `DHRDATA`    | `XLEN` |   Input   | Data read data                                        |
| `DHWDATA`    | `XLEN` |   Output  | Data write data                                       |
| `DHWRITE`    |    1   |   Output  | Data write                                            |
| `DHSIZE`     |    3   |   Output  | Transfer size                                         |
| `DHBURST`    |    3   |   Output  | Transfer burst size                                   |
| `DHPROT`     |    4   |   Output  | Transfer protection level                             |
| `DHTRANS`    |    2   |   Output  | Transfer type                                         |
| `DHMASTLOCK` |    1   |   Output  | Transfer master lock                                  |
| `DHREADY`    |    1   |   Input   | Slave Ready Indicator                                 |
| `DHRESP`     |    1   |   Input   | Data Transfer Response                                |


## Data INPUTS/OUTPUTS Wishbone Bus

| Port    |  Size  | Direction | Description                     |
| --------| ------ | --------- | ------------------------------- |
| `rst`   |    1   |   Input   | Synchronous, active high        |
| `clk`   |    1   |   Input   | Master clock                    |
|         |        |           |                                 |
| `dadr`  | `PLEN` |   Input   | Lower address bits              |
| `ddati` | `XLEN` |   Input   | Data towards the core           |
| `ddato` | `XLEN` |   Output  | Data from the core              |
| `dsel`  |    4   |   Input   | Byte select signals             |
| `dwe`   |    1   |   Input   | Write enable input              |
| `dstb`  |    1   |   Input   | Strobe signal/Core select input |
| `dcyc`  |    1   |   Input   | Valid bus cycle input           |
| `dack`  |    1   |   Output  | Bus cycle acknowledge output    |
| `derr`  |    1   |   Output  | Bus cycle error output          |
| `dint`  |    1   |   Output  | Interrupt signal output         |


## Count Lines of Code

|Language              | files | blank | comment | code |
| ---------------------| ----- | ----- | ------- | ---- |
|VHDL                  |    21 |   784 |    1859 | 5432 |
|Verilog-SystemVerilog |    21 |   690 |    1670 | 3669 |


## Hardware Description Language

dbg
├── bench
│   ├── verilog
│   │   └── regression
│   │       └── mpsoc_dbg_testbench.sv
│   └── vhdl
│       └── regression
│           └── mpsoc_dbg_testbench.vhd
├── doc
│   └── WIKI-DBG-MPSoC.md
├── rtl
│   ├── verilog
│   │   ├── ahb3
│   │   │   ├── mpsoc_dbg_ahb3_biu.sv
│   │   │   ├── mpsoc_dbg_ahb3_module.sv
│   │   │   ├── mpsoc_dbg_jsp_apb_biu.sv
│   │   │   ├── mpsoc_dbg_jsp_apb_module.sv
│   │   │   └── mpsoc_dbg_top_ahb3.sv
│   │   ├── core
│   │   │   ├── mpsoc_dbg_bus_module_core.sv
│   │   │   ├── mpsoc_dbg_bytefifo.sv
│   │   │   ├── mpsoc_dbg_crc32.sv
│   │   │   ├── mpsoc_dbg_jsp_module_core.sv
│   │   │   ├── mpsoc_dbg_or1k_biu.sv
│   │   │   ├── mpsoc_dbg_or1k_module.sv
│   │   │   ├── mpsoc_dbg_or1k_status_reg.sv
│   │   │   ├── mpsoc_dbg_syncflop.sv
│   │   │   └── mpsoc_dbg_syncreg.sv
│   │   ├── pkg
│   │   │   └── mpsoc_dbg_pkg.sv
│   │   └── wb
│   │       ├── mpsoc_dbg_jsp_wb_biu.sv
│   │       ├── mpsoc_dbg_jsp_wb_module.sv
│   │       ├── mpsoc_dbg_top_wb.sv
│   │       ├── mpsoc_dbg_wb_biu.sv
│   │       └── mpsoc_dbg_wb_module.sv
│   └── vhdl
│       ├── ahb3
│       │   ├── mpsoc_dbg_ahb3_biu.vhd
│       │   ├── mpsoc_dbg_ahb3_module.vhd
│       │   ├── mpsoc_dbg_jsp_apb_biu.vhd
│       │   ├── mpsoc_dbg_jsp_apb_module.vhd
│       │   └── mpsoc_dbg_top_ahb3.vhd
│       ├── core
│       │   ├── mpsoc_dbg_bus_module_core.vhd
│       │   ├── mpsoc_dbg_bytefifo.vhd
│       │   ├── mpsoc_dbg_crc32.vhd
│       │   ├── mpsoc_dbg_jsp_module_core.vhd
│       │   ├── mpsoc_dbg_or1k_biu.vhd
│       │   ├── mpsoc_dbg_or1k_module.vhd
│       │   ├── mpsoc_dbg_or1k_status_reg.vhd
│       │   ├── mpsoc_dbg_syncflop.vhd
│       │   └── mpsoc_dbg_syncreg.vhd
│       ├── pkg
│       │   └── mpsoc_dbg_pkg.vhd
│       └── wb
│           ├── mpsoc_dbg_jsp_wb_biu.vhd
│           ├── mpsoc_dbg_jsp_wb_module.vhd
│           ├── mpsoc_dbg_top_wb.vhd
│           ├── mpsoc_dbg_wb_biu.vhd
│           └── mpsoc_dbg_wb_module.vhd
├── sim
│   ├── mixed
│   │   └── regression
│   │       └── bin
│   │           ├── mpsoc_dbg_verilog.vc
│   │           ├── mpsoc_dbg_vhdl.vc
│   │           ├── Makefile
│   │           ├── run.do
│   │           └── transcript
│   ├── verilog
│   │   └── regression
│   │       └── bin
│   │           ├── mpsoc_dbg.vc
│   │           ├── Makefile
│   │           ├── run.do
│   │           └── transcript
│   └── vhdl
│       └── regression
│           └── bin
│               ├── mpsoc_dbg.vc
│               ├── Makefile
│               ├── run.do
│               └── transcript
├── system.vtor
├── system.qf
├── system.ys
├── README.md
├── CLEAN-IT
├── DELETE-IT
├── EXECUTE-IT
├── SIMULATE-MIXED-MS-IT
├── SIMULATE-VHDL-GHDL-IT
├── SIMULATE-VHDL-MS-IT
├── SIMULATE-VLOG-IV-IT
├── SIMULATE-VLOG-MS-IT
├── SIMULATE-VLOG-VTOR-DBG-IT
├── SYNTHESIZE-VLOG-YS-IT
├── TRANSLATE-IT
└── UPLOAD-IT
