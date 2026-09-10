# AHB to APB Bridge

A synthesizable Verilog implementation of an AMBA AHB-to-APB bridge. The bridge acts as an **AHB slave** and an **APB master**, translating pipelined AHB transfers from a high-performance system bus into two-cycle (Setup/Access) APB transfers for low-power peripherals. The design was simulated in ModelSim and synthesized with Quartus Prime for an Intel/Altera Cyclone V FPGA.

## Table of Contents

- [About the AMBA Buses](#about-the-amba-buses)
- [Basic Terminology](#basic-terminology)
- [AMBA Signals](#amba-signals)
- [Implementation](#implementation)
  - [Objective](#objective)
  - [Toolchain](#toolchain)
  - [Repository Structure](#repository-structure)
  - [Architecture](#architecture)
  - [Design Modules](#design-modules)
  - [Testbench Models](#testbench-models)
  - [Transaction Lifecycle](#transaction-lifecycle)
  - [Known Limitations](#known-limitations)
- [Building and Simulating](#building-and-simulating)
- [Simulation Results](#simulation-results)
- [Synthesis Results](#synthesis-results)
- [Key Concepts](#key-concepts)
- [Further Work](#further-work)
- [Documentation](#documentation)

## About the AMBA Buses

The Advanced Microcontroller Bus Architecture (AMBA) specification defines an
on-chip communications standard for designing high-performance embedded
microcontrollers.
Three distinct buses are defined within the AMBA specification:
- Advanced High-performance Bus (AHB)
- Advanced System Bus (ASB)
- Advanced Peripheral Bus (APB).

### Advanced High-performance Bus (AHB)

The AMBA AHB is for high-performance, high clock frequency system modules.
The AHB acts as the high-performance system backbone bus. AHB supports the
efficient connection of processors, on-chip memories and off-chip external memory
interfaces with low-power peripheral macrocell functions. AHB is also specified to
ensure ease of use in an efficient design flow using synthesis and automated test
techniques.

### Advanced System Bus (ASB)

The AMBA ASB is for high-performance system modules.
AMBA ASB is an alternative system bus suitable for use where the high-performance
features of AHB are not required. ASB also supports the efficient connection of
processors, on-chip memories and off-chip external memory interfaces with low-power
peripheral macrocell functions.

### Advanced Peripheral Bus (APB)

The AMBA APB is for low-power peripherals.
AMBA APB is optimized for minimal power consumption and reduced interface
complexity to support peripheral functions. APB can be used in conjunction with either
version of the system bus.

A bridge is required because the AHB and APB domains use different protocols and timing. AHB serves high-bandwidth components such as processors and memory, while APB serves low-bandwidth peripherals such as UARTs and timers. The bridge sits between the two, responding as a slave on the AHB and driving the peripherals as the master on the APB.

The overall architecture looks like the following:

![AMBA System](https://user-images.githubusercontent.com/91010702/194475317-68a7f60d-65ea-48de-a13a-fd85e25c364b.png)

## Basic Terminology

#### Bus cycle
A bus cycle is a basic unit of one bus clock period and for the
purpose of AMBA AHB or APB protocol descriptions is defined
from rising-edge to rising-edge transitions.

#### Bus transfer
An AMBA ASB or AHB bus transfer is a read or write operation of a data object, which may take one or more bus cycles. The bus
transfer is terminated by a completion response from the
addressed slave.
An AMBA APB bus transfer is a read or write operation
of a data object, which always requires two bus cycles.

#### Burst operation
A burst operation is defined as one or more data transactions,
initiated by a bus master, which have a consistent width of
transaction to an incremental region of address space. The
increment step per transaction is determined by the width of
transfer (byte, halfword, word). No burst operation is supported
on the APB.

## AMBA Signals

### AMBA AHB Signals

| Name | Source | Description |
| ----------- | ----------- |  ----------- |
| HCLK | Clock source |  This clock times all bus transfers. All signal timings are related to the rising edge of HCLK. |
| HRESETn | Reset controller | The bus reset signal is active LOW and is used to reset the system and the bus.This is the only active LOW signal. |
| HADDR[31:0] | Master | The 32-bit system address bus. |
| HTRANS[1:0] | Master | Indicates the type of the current transfer, which can be NONSEQUENTIAL, SEQUENTIAL, IDLE or BUSY. |
| HWRITE | Master | When HIGH this signal indicates a write transfer and when LOW a read transfer. |
| HSIZE[2:0] | Master | Indicates the size of the transfer, which is typically byte (8-bit), halfword (16-bit) or word (32-bit). The protocol allows for larger transfer sizes up to a maximum of 1024 bits. |
| HBURST[2:0] | Master | Indicates if the transfer forms part of a burst. Four, eight and sixteen beat bursts are supported and the burst may be either incrementing or wrapping. |
| HPROT[3:0] | Master | The protection control signals provide additional information about a bus access and are primarily intended for use by any module that wishes to implement some level of protection. This is optional |
| HWDATA[31:0] | Master | The write data bus is used to transfer data from the master to the bus slaves during write operations. A minimum data bus width of 32 bits is recommended. |
| HSELx | Decoder | Each AHB slave has its own slave select signal and this signal indicates that the current transfer is intended for the selected slave. This signal is simply a combinatorial decode of the address bus. |
| HRDATA[31:0] | Slave | The read data bus is used to transfer data from bus slaves to the bus master during read operations. A minimum data bus width of 32 bits is recommended.|
| HREADY | Slave | When HIGH the HREADY signal indicates that a transfer has finished on the bus. This signal may be driven LOW to extend a transfer. **Note: Slaves on the bus require HREADY as both an input and an output signal.** |
| HRESP[1:0] | Slave |  The transfer response provides additional information on the status of a transfer. Four different responses are provided, OKAY, ERROR, RETRY and SPLIT. |

### AMBA APB Signals

| Name | Source | Description |
| ----------- | ----------- |  ----------- |
|PCLK  | Clock Source|The rising edge of PCLK is used to time all transfers on the APB.|
|PRESETn  | Reset Controller| The APB bus reset signal is active LOW and this signal will normally be connected directly to the system bus reset signal.|
|PADDR[31:0]  | Master |This is the APB address bus, which may be up to 32-bits wide and is driven by the peripheral bus bridge unit.|
|PSELx  | Decoder | A signal from the secondary decoder, within the peripheral bus bridge unit, to each peripheral bus slave x. This signal indicates that the slave device is selected and a data transfer is required. There is a PSELx signal for each bus slave.|
|PENABLE  |  Master | This strobe signal is used to time all accesses on the peripheral bus. The enable signal is used to indicate the second cycle of an APB transfer. The rising edge of PENABLE occurs in the middle of the APB transfer.|
|PWRITE  |  Master | When HIGH this signal indicates an APB write access and when LOW a read access.|
|PRDATA[31:0]  | Slave | The read data bus is driven by the selected slave during read cycles (when PWRITE is LOW). The read data bus can be up to 32-bits wide.|
|PWDATA[31:0]  | Master | The write data bus is driven by the peripheral bus bridge unit during write cycles (when PWRITE is HIGH). The write data bus can be up to 32-bits wide.|

# Implementation

## Objective

To design and simulate a synthesizable AHB to APB bridge interface using Verilog and run single read and single write tests using AHB Master and APB Slave testbenches.
The bridge unit converts system bus transfers into APB transfers and performs the following functions:
- Latches the address and holds it valid throughout the transfer.
- Decodes the address and generates a peripheral select, PSELx. Only one select signal can be active during a transfer.
- Drives the data onto the APB for a write transfer.
- Drives the APB data onto the system bus for a read transfer.
- Generates a timing strobe, PENABLE, for the transfer
- Can implement single read and write operations successfully.

The diagram below shows the interface:

![APB Bridge](https://user-images.githubusercontent.com/91010702/194486314-3df5f435-e9f7-43a7-bd94-d5e2070f09c0.png)

## Toolchain

| Component | Tool / Target |
| --- | --- |
| HDL | Verilog |
| Simulator | ModelSim |
| Synthesis | Quartus Prime |
| FPGA family | Intel/Altera Cyclone V |
| Device | 5CSXFC6D6F31I7ES |

The sources also compile with the open-source Icarus Verilog (`iverilog`); see [Building and Simulating](#building-and-simulating).

## Repository Structure

| File | Role | Synthesizable |
| --- | --- | --- |
| `bridge_top.v` | `Bridge_Top`: top-level wrapper that instantiates and wires the AHB slave interface and the APB FSM controller | Yes |
| `AHB_Slave_Interface.v` | `AHB_slave_interface`: AHB protocol front-end, address/data pipeline, `valid` generation and peripheral address decoder | Yes |
| `APB_Controller.v` | `APB_FSM_Controller`: 8-state FSM that generates APB Setup/Access timing and drives `Hreadyout` | Yes |
| `AHB_Master.v` | `AHB_Master`: testbench stimulus model with `single_write` and `single_read` tasks | No (testbench only) |
| `APB_Interface.v` | `APB_Interface`: APB slave placeholder that passes signals through and returns random read data | No (testbench only) |
| `AMBA System.png` | AMBA system block diagram | - |

Only the bridge (`bridge_top.v`, `AHB_Slave_Interface.v`, `APB_Controller.v`) is synthesizable. `AHB_Master.v` and `APB_Interface.v` exist solely to generate and observe read/write traffic in simulation.

## Architecture

`Bridge_Top` is a purely structural module. It exposes the AHB slave port on one side and the APB master port on the other and connects two sub-modules through a set of internal wires.

```
                    +-------------------------------------------------------+
                    |                      Bridge_Top                       |
  AHB Master        |                                                       |        APB Slaves
 ------------>      |  +---------------------+      +--------------------+  |      ------------>
  Haddr, Hwdata     |  | AHB_slave_interface |      | APB_FSM_Controller |  |  Paddr, Pwdata, Pwrite
  Htrans, Hwrite    |  |     (AHBSlave)      |      |    (APBControl)    |  |  Pselx[2:0], Penable
  Hreadyin          |  |                     |      |                    |  |
                    |  |  valid ------------------> |                    |  |
 <------------      |  |  Haddr1, Haddr2 ---------> |                    |  |      <------------
  Hrdata, Hresp     |  |  Hwdata1, Hwdata2 -------> |                    |  |  Prdata
  Hreadyout         |  |  Hwritereg --------------> |                    |  |
                    |  |  tempselx[2:0] ----------> |                    |  |
                    |  +---------------------+      +--------------------+  |
                    +-------------------------------------------------------+
```

### Top-level ports (`Bridge_Top`)

| Domain | Signal | Direction | Width | Description |
| --- | --- | --- | --- | --- |
| System | `Hclk` | Input | 1 | Clock; all logic runs on the rising edge of `Hclk` |
| System | `Hresetn` | Input | 1 | Active-low reset |
| AHB slave | `Hwrite` | Input | 1 | 1 = write, 0 = read |
| AHB slave | `Hreadyin` | Input | 1 | Previous AHB transfer complete |
| AHB slave | `Htrans` | Input | 2 | Transfer type (IDLE, BUSY, NONSEQ, SEQ) |
| AHB slave | `Haddr` | Input | 32 | AHB address bus |
| AHB slave | `Hwdata` | Input | 32 | AHB write data bus |
| AHB slave | `Hrdata` | Output | 32 | Read data returned to the AHB master |
| AHB slave | `Hreadyout` | Output | 1 | Driven low to stall the AHB master while an APB transfer is in progress |
| AHB slave | `Hresp` | Output | 2 | Transfer response (always OKAY) |
| APB master | `Pselx` | Output | 3 | One-hot select for up to three APB peripherals |
| APB master | `Penable` | Output | 1 | APB Access-phase strobe |
| APB master | `Pwrite` | Output | 1 | APB write/read control |
| APB master | `Paddr` | Output | 32 | APB address bus |
| APB master | `Pwdata` | Output | 32 | APB write data bus |
| APB master | `Prdata` | Input | 32 | Read data from the selected APB peripheral |

### Internal wires

| Wire | Description |
| --- | --- |
| `valid` | Combinational flag from the slave interface indicating a transfer is targeted at the bridge |
| `Haddr1`, `Haddr2` | One- and two-cycle delayed copies of `Haddr` |
| `Hwdata1`, `Hwdata2` | One- and two-cycle delayed copies of `Hwdata` |
| `Hwritereg` | Registered copy of `Hwrite` |
| `tempselx` | 3-bit one-hot pre-decoded peripheral select |

## Design Modules

### AHB Slave Interface (`AHB_Slave_Interface.v`)

An AHB bus slave responds to transfers initiated by bus masters within the system. This module is the AHB-facing front-end of the bridge and is responsible for:

- **Pipeline registers.** On every rising edge of `Hclk`, `Haddr` is shifted into `Haddr1` and then `Haddr2`, `Hwdata` into `Hwdata1` and then `Hwdata2`, and `Hwrite` into `Hwritereg`. All registers clear to 0 while `Hresetn` is low. These delayed copies align the AHB address phase with the later APB Setup and Access cycles.
- **Valid logic.** `valid` is a combinational signal that is asserted only when all of the following hold:
  1. `Hresetn` is high
  2. `Hreadyin` is high
  3. `Haddr` is within `0x8000_0000` to `0x8BFF_FFFF`
  4. `Htrans` is `NONSEQ` (`2'b10`) or `SEQ` (`2'b11`)
- **Address decoding.** `tempselx` is a one-hot pre-decode of `Haddr` into three 64 MB peripheral slots:

  | Address range | `tempselx` | Peripheral slot |
  | --- | --- | --- |
  | `0x8000_0000` - `0x83FF_FFFF` | `3'b001` | Slot 1 |
  | `0x8400_0000` - `0x87FF_FFFF` | `3'b010` | Slot 2 |
  | `0x8800_0000` - `0x8BFF_FFFF` | `3'b100` | Slot 3 |
  | any other address | `3'b000` | none |

- **Response and read data.** `Hresp` is constantly `2'b00` (OKAY) and `Hrdata` is a direct pass-through of `Prdata`.

### APB Controller (`APB_Controller.v`)

The `APB_FSM_Controller` is the state machine that turns AHB requests into APB-compliant Setup and Access phases and generates the wait states seen by the AHB master. It has eight states:

| State | Encoding | Description |
| --- | --- | --- |
| `ST_IDLE` | `3'b000` | Bridge idle; no APB transfer in progress |
| `ST_WWAIT` | `3'b001` | Write wait; waits one cycle for the AHB data phase before the APB write Setup phase |
| `ST_READ` | `3'b010` | APB read Setup phase (`Pselx` asserted, `Penable` low) |
| `ST_WRITE` | `3'b011` | APB write Setup phase for a non-pipelined write |
| `ST_WRITEP` | `3'b100` | APB write Setup phase for a pipelined (back-to-back) write |
| `ST_RENABLE` | `3'b101` | APB read Access phase (`Penable` high) |
| `ST_WENABLE` | `3'b110` | APB write Access phase for a single write |
| `ST_WENABLEP` | `3'b111` | APB write Access phase for a pipelined write |

Transitions are driven by `valid`, `Hwrite` and `Hwritereg`:

| From | Condition | To |
| --- | --- | --- |
| `ST_IDLE` | `valid && Hwrite` | `ST_WWAIT` |
| `ST_IDLE` | `valid && !Hwrite` | `ST_READ` |
| `ST_IDLE` | `!valid` | `ST_IDLE` |
| `ST_WWAIT` | `!valid` | `ST_WRITE` |
| `ST_WWAIT` | `valid` | `ST_WRITEP` |
| `ST_READ` | always | `ST_RENABLE` |
| `ST_WRITE` | `!valid` | `ST_WENABLE` |
| `ST_WRITE` | `valid` | `ST_WENABLEP` |
| `ST_WRITEP` | always | `ST_WENABLEP` |
| `ST_RENABLE` / `ST_WENABLE` | `!valid` | `ST_IDLE` |
| `ST_RENABLE` / `ST_WENABLE` | `valid && Hwrite` | `ST_WWAIT` |
| `ST_RENABLE` / `ST_WENABLE` | `valid && !Hwrite` | `ST_READ` |
| `ST_WENABLEP` | `!valid && Hwritereg` | `ST_WRITE` |
| `ST_WENABLEP` | `valid && Hwritereg` | `ST_WRITEP` |
| `ST_WENABLEP` | `!Hwritereg` | `ST_READ` |

Output behaviour:

- Combinational logic computes `*_temp` versions of `Paddr`, `Pwdata`, `Pwrite`, `Pselx`, `Penable` and `Hreadyout` from the present state and the pipelined AHB signals; these are registered on the rising edge of `Hclk`, so all APB outputs are synchronous to the AHB clock.
- `Hreadyout` is driven low during Setup phases (`ST_WWAIT`, `ST_READ`, `ST_WRITE`, `ST_WRITEP`) to stall the AHB master and high during Access phases (`ST_RENABLE`, `ST_WENABLE`, `ST_WENABLEP`) and `ST_IDLE`.
- `Pselx` is driven from `tempselx` so that exactly one peripheral is selected per transfer.
- Pipelined writes use `Haddr2` / `Hwdata1` in `ST_WENABLEP` so that a second write can be issued immediately after the first completes.
- On reset all APB outputs and `Hreadyout` are cleared to 0.

## Testbench Models

### AHB Master (`AHB_Master.v`)

A bus-functional stimulus model that abstracts AHB timing into two Verilog tasks:

- `single_write()`: drives `Htrans = NONSEQ`, `Hwrite = 1`, `Hreadyin = 1`, `Haddr = 0x8000_0001` in the address phase, then `Hwdata = 0xA3` and `Htrans = IDLE` in the data phase.
- `single_read()`: drives `Htrans = NONSEQ`, `Hwrite = 0`, `Hreadyin = 1`, `Haddr = 0x8000_00A2` in the address phase, then `Htrans = IDLE`.

Both tasks hard-code `Hsize = 3'b000` (byte) and `Hburst = 3'b000` (SINGLE), matching the single-transfer scope of the bridge.

### APB Slave (`APB_Interface.v`)

A placeholder APB peripheral used for waveform observation:

- Passes `Pwrite`, `Pselx`, `Penable`, `Paddr` and `Pwdata` straight through to `*out` ports.
- Returns a random 8-bit value on `Prdata` whenever `~Pwrite && Penable` (the Access phase of a read), and 0 otherwise.

## Transaction Lifecycle

1. **AHB address phase.** The master drives `Haddr`, `Htrans` and `Hwrite`. The slave interface decodes the address and asserts `valid` and `tempselx`.
2. **AHB data phase / APB Setup phase.** For a write the master drives `Hwdata`. The FSM leaves `ST_IDLE` for `ST_WWAIT` (write) or `ST_READ` (read), drives `Paddr`, `Pwrite` and `Pselx`, and pulls `Hreadyout` low to insert a wait state on the AHB.
3. **APB Access phase.** The FSM asserts `Penable`. Write data is presented on `Pwdata`, or read data is captured from `Prdata` and forwarded on `Hrdata`. `Hreadyout` returns high, completing the AHB transfer.

## Known Limitations

- The bridge only responds to addresses in `0x8000_0000` - `0x8BFF_FFFF`; the address map is hard-coded.
- Only single (non-burst) transfers are supported. `Hsize` and `Hburst` are not used by the bridge.
- `Hresp` is always OKAY; no ERROR, RETRY or SPLIT responses are generated.
- The APB slave is assumed to be always ready; there is no `PREADY` or `PSLVERR` handling.
- The repository does not include a top-level self-checking testbench that instantiates `Bridge_Top`, `AHB_Master` and `APB_Interface` together. The simulation results below were produced interactively in ModelSim.

## Building and Simulating

The RTL was developed with ModelSim and Quartus Prime, but the sources also compile with [Icarus Verilog](http://iverilog.icarus.com/):

```sh
# Compile all sources
iverilog -o /tmp/all.out *.v

# Lint with all warnings enabled
iverilog -Wall -tnull *.v

# Run (elaborates the design; produces no output because there is no top-level stimulus)
vvp /tmp/all.out
```

Compiling emits two benign warnings about empty task port declaration lists in `AHB_Master.v`. To simulate a transaction, write a top-level testbench that instantiates `Bridge_Top`, `AHB_Master` and `APB_Interface`, generates `Hclk` / `Hresetn`, and calls the `single_write` / `single_read` tasks on the master.

For FPGA synthesis, add only `bridge_top.v`, `AHB_Slave_Interface.v` and `APB_Controller.v` to a Quartus Prime project targeting Cyclone V (device 5CSXFC6D6F31I7ES) with `Bridge_Top` as the top-level entity.

# Simulation Results

It consists of a write operation followed by a read operation on the AHB Bus which is successfully mapped to the APB bus according to the interfacing.

![simulation_AHBtoAPB](https://user-images.githubusercontent.com/91010702/194483573-0e104260-c1b7-4810-88fe-c9aa4a32395f.png)

# Synthesis Results

RTL Model:
![bridge_rtl](https://user-images.githubusercontent.com/91010702/194485990-f8ff7727-387e-42ef-8fa7-d39034216ffc.png)

State Machine Viewer:
![bridge_fsm](https://user-images.githubusercontent.com/91010702/194485981-4a8f44e9-390b-4100-84b3-abe9c4930377.png)

# Key Concepts

| Term | Meaning |
| --- | --- |
| AHB slave | The bridge's role on the system bus: it responds to transfers initiated by AHB masters |
| APB master | The bridge's role on the peripheral bus: it drives `Paddr`, `Pwdata`, `Pselx`, `Penable` and `Pwrite` to the peripherals |
| Two-phase transfer | AHB pipelining in which the address phase of one transfer overlaps the data phase of the previous one |
| Setup phase | First cycle of an APB transfer: `PSELx` high, `PENABLE` low |
| Access phase | Second cycle of an APB transfer: `PSELx` and `PENABLE` both high; data is transferred |
| Address latching | Registering `Haddr` into `Haddr1` / `Haddr2` so the address stays stable across the APB cycles |
| Valid logic | Combinational check that a transfer is in range, is NONSEQ/SEQ, and the bus is ready |
| `tempselx` | Internal one-hot pre-decode of the address into one of three peripheral slots; drives `Pselx` |
| `Hwritereg` | Registered `Hwrite`, used to keep read/write intent consistent across FSM states |
| `HREADYout` | Flow-control signal driven low by the bridge to stall the AHB master during APB Setup phases |
| FSM controller | The eight-state machine in `APB_FSM_Controller` that sequences Setup and Access phases |
| Pipelined write | Back-to-back writes handled through `ST_WRITEP` / `ST_WENABLEP` without returning to idle |

# Further Work

- Include functionality for burst read and burst write operations in AHB Master
- Include an arbitration mechanism and arbitration signals to generalise the testbench
- Add a top-level self-checking testbench so the design can be regression-tested from the command line

# Documentation

- AMBA Modules | Chapter 4 | [AMBA Modules.pdf](https://github.com/prajwalgekkouga/AHB-to-APB-Bridge/files/9731505/AMBA.Modules.pdf)
- AMBA Specifications | Chapter 1,2,3 and 5 | [AMBA Specifications.pdf](https://github.com/prajwalgekkouga/AHB-to-APB-Bridge/files/9731507/AMBA.Specifications.pdf)
