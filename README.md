# AHB-to-APB Bridge

A synthesizable AHB-to-APB bridge interface implemented in Verilog, enabling communication between high-performance AHB masters and low-power APB peripherals. The bridge translates pipelined AHB transactions into two-phase APB transfers, supporting single read and write operations across a 192 MB address space mapped to up to three APB peripherals.

---

## Table of Contents

- [About the AMBA Buses](#about-the-amba-buses)
- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Signal Descriptions](#signal-descriptions)
- [Design Modules](#design-modules)
- [Address Map](#address-map)
- [FSM State Machine](#fsm-state-machine)
- [Simulation and Synthesis](#simulation-and-synthesis)
- [Tools and Target Device](#tools-and-target-device)
- [Results](#results)
- [Further Work](#further-work)
- [References](#references)
- [Basic Terminology](#basic-terminology)

---

## About the AMBA Buses

The **Advanced Microcontroller Bus Architecture (AMBA)** specification defines an on-chip communications standard for designing high-performance embedded microcontrollers. Three distinct buses are defined within the AMBA specification:

| Bus | Full Name | Purpose |
|-----|-----------|---------|
| **AHB** | Advanced High-performance Bus | High-performance, high-clock-frequency system modules (processors, on-chip memories, external memory interfaces) |
| **ASB** | Advanced System Bus | Alternative system bus for designs where AHB's high-performance features are not required |
| **APB** | Advanced Peripheral Bus | Low-power peripherals with minimal interface complexity; uses a simple two-phase transfer protocol |

The diagram below shows a typical AMBA system topology, with the AHB-to-APB bridge connecting the high-speed system bus to low-power peripheral devices:

![AMBA System](https://user-images.githubusercontent.com/91010702/194475317-68a7f60d-65ea-48de-a13a-fd85e25c364b.png)

---

## Architecture Overview

The bridge implements a **two-stage pipeline architecture**:

```
AHB Master --> AHB Slave Interface --> APB FSM Controller --> APB Peripherals
               (Stage 1: Capture)     (Stage 2: Convert)
```

**Stage 1 - AHB Slave Interface** captures incoming AHB transactions, pipelines address and data signals across two clock cycles, validates the transfer, and decodes the target address into a peripheral select.

**Stage 2 - APB FSM Controller** uses an 8-state finite state machine to convert the captured AHB transaction into the APB two-phase protocol (setup phase + enable phase), generating all required APB control and data signals.

The bridge performs the following functions:
- Latches the address and holds it valid throughout the transfer
- Decodes the address and generates a peripheral select (`PSELx`); only one select signal can be active during a transfer
- Drives data onto the APB for write transfers
- Drives APB read data back onto the system bus for read transfers
- Generates the timing strobe `PENABLE` for each transfer

![APB Bridge Interface](https://user-images.githubusercontent.com/91010702/194486314-3df5f435-e9f7-43a7-bd94-d5e2070f09c0.png)

---

## Repository Structure

| File | Module | Type | Description |
|------|--------|------|-------------|
| `bridge_top.v` | `Bridge_Top` | Synthesizable | Top-level wrapper; instantiates and connects `AHB_slave_interface` and `APB_FSM_Controller` |
| `AHB_Slave_Interface.v` | `AHB_slave_interface` | Synthesizable | AHB protocol handler: pipelines address/data, generates `valid` signal, decodes addresses to `tempselx` |
| `APB_Controller.v` | `APB_FSM_Controller` | Synthesizable | 8-state FSM that generates APB transaction timing and control signals |
| `AHB_Master.v` | `AHB_Master` | Testbench | Transaction generator with `single_write()` and `single_read()` tasks for verification |
| `APB_Interface.v` | `APB_Interface` | Testbench | APB slave simulator; passes through APB signals and generates random read data |
| `AMBA System.png` | -- | Documentation | Architecture diagram of the AMBA system topology |

> **Note:** Only the bridge core (`bridge_top.v`, `AHB_Slave_Interface.v`, `APB_Controller.v`) is synthesizable. The master and APB interface modules are testbench components used solely for verification.

---

## Signal Descriptions

### AHB Signals

| Signal | Width | Source | Description |
|--------|-------|--------|-------------|
| `HCLK` | 1 | Clock source | Bus clock; all signal timings are referenced to the rising edge |
| `HRESETn` | 1 | Reset controller | Active-LOW bus reset signal |
| `HADDR[31:0]` | 32 | Master | System address bus |
| `HTRANS[1:0]` | 2 | Master | Transfer type: `NONSEQUENTIAL` (2'b10), `SEQUENTIAL` (2'b11), `IDLE` (2'b00), or `BUSY` (2'b01) |
| `HWRITE` | 1 | Master | HIGH = write transfer, LOW = read transfer |
| `HSIZE[2:0]` | 3 | Master | Transfer size: byte (8-bit), halfword (16-bit), or word (32-bit) |
| `HBURST[2:0]` | 3 | Master | Burst type: single, 4/8/16-beat incrementing or wrapping |
| `HPROT[3:0]` | 4 | Master | Protection control signals (optional) |
| `HWDATA[31:0]` | 32 | Master | Write data bus (master to slave) |
| `HSELx` | 1 | Decoder | Slave select; combinatorial decode of the address bus |
| `HRDATA[31:0]` | 32 | Slave | Read data bus (slave to master) |
| `HREADY` | 1 | Slave | HIGH = transfer complete; LOW = extend transfer. Serves as both input and output for slaves |
| `HRESP[1:0]` | 2 | Slave | Transfer response: `OKAY`, `ERROR`, `RETRY`, or `SPLIT` |

### APB Signals

| Signal | Width | Source | Description |
|--------|-------|--------|-------------|
| `PCLK` | 1 | Clock source | APB clock; rising edge times all transfers |
| `PRESETn` | 1 | Reset controller | Active-LOW APB reset (typically connected to system reset) |
| `PADDR[31:0]` | 32 | Bridge | APB address bus, driven by the bridge |
| `PSELx` | 3 | Bridge | One-hot peripheral select (one bit per APB slave) |
| `PENABLE` | 1 | Bridge | Strobe signal indicating the second cycle (enable phase) of an APB transfer |
| `PWRITE` | 1 | Bridge | HIGH = write access, LOW = read access |
| `PRDATA[31:0]` | 32 | Slave | Read data bus, driven by the selected slave during read cycles |
| `PWDATA[31:0]` | 32 | Bridge | Write data bus, driven by the bridge during write cycles |

### Internal Bridge Signals

| Signal | Width | Description |
|--------|-------|-------------|
| `valid` | 1 | Asserted when `HRESETn` is high, `HREADYIN` is high, address is in range `0x8000_0000`-`0x8C00_0000`, and `HTRANS` is `NONSEQ` or `SEQ` |
| `tempselx[2:0]` | 3 | One-hot address decode output selecting one of three peripheral regions |
| `Haddr1[31:0]` | 32 | First pipeline stage of `HADDR` (1-cycle delayed) |
| `Haddr2[31:0]` | 32 | Second pipeline stage of `HADDR` (2-cycle delayed) |
| `Hwdata1[31:0]` | 32 | First pipeline stage of `HWDATA` (1-cycle delayed) |
| `Hwdata2[31:0]` | 32 | Second pipeline stage of `HWDATA` (2-cycle delayed) |
| `Hwritereg` | 1 | Pipelined `HWRITE` (1-cycle delayed); used by the FSM for pipelined transaction decisions |

---

## Design Modules

### AHB Slave Interface (`AHB_Slave_Interface.v`)

The AHB slave interface is responsible for:

1. **Pipeline Logic** - Registers `HADDR` and `HWDATA` across two sequential stages (`Haddr1`/`Haddr2`, `Hwdata1`/`Hwdata2`) so that address and data are available when needed by the APB controller. The `HWRITE` signal is also registered as `Hwritereg`.

2. **Valid Generation** - Combines four conditions to produce the `valid` signal:
   - `HRESETn` is asserted (not in reset)
   - `HREADYIN` is asserted (bus ready)
   - Address is within the bridge's window (`0x8000_0000` to `0x8C00_0000`)
   - Transfer type is `NONSEQUENTIAL` (2'b10) or `SEQUENTIAL` (2'b11)

3. **Address Decoding** - Maps the 192 MB address space into three 64 MB regions, generating a one-hot `tempselx` output (see [Address Map](#address-map)).

4. **Read Data Pass-through** - `HRDATA` is directly assigned from `PRDATA`.

5. **Response** - `HRESP` is hardcoded to `2'b00` (`OKAY`).

### APB FSM Controller (`APB_Controller.v`)

The APB controller implements an 8-state FSM that drives APB transaction timing. See [FSM State Machine](#fsm-state-machine) for the full state diagram.

Key behaviors:
- **Output registration** - All APB outputs (`Paddr`, `Pwdata`, `Pselx`, `Penable`, `Pwrite`) and `Hreadyout` are registered on the rising clock edge for glitch-free operation.
- **Flow control** - `Hreadyout` is driven LOW during APB setup phases to stall the AHB master, and HIGH during enable phases to signal transfer completion.

#### Transaction Latency

| Operation | Path | AHB Cycles |
|-----------|------|------------|
| Single Read | `IDLE` -> `READ` -> `RENABLE` | 3 |
| Single Write | `IDLE` -> `WWAIT` -> `WRITE` -> `WENABLE` | 4 |

### Bridge Top (`bridge_top.v`)

Top-level wrapper that instantiates:
- `AHBSlave` (instance of `AHB_slave_interface`)
- `APBControl` (instance of `APB_FSM_Controller`)

All intermediate signals (`valid`, `Haddr1`, `Haddr2`, `Hwdata1`, `Hwdata2`, `Hwritereg`, `tempselx`) are routed between the two sub-modules via internal wires.

### Testbench Modules

**`AHB_Master.v`** (`AHB_Master`) - Provides two verification tasks:
- `single_write()` - Generates a write transaction to address `0x8000_0001` with data `0xA3`
- `single_read()` - Generates a read transaction from address `0x8000_00A2`

**`APB_Interface.v`** (`APB_Interface`) - Simulates an APB slave by passing through all APB control/address/data signals and generating a random `PRDATA` value (0-255) during read enable phases.

---

## Address Map

The bridge responds to a 192 MB address window divided into three 64 MB regions, each mapped to a separate APB peripheral:

| Region | Address Range | `tempselx` | Peripheral |
|--------|--------------|------------|------------|
| 0 | `0x8000_0000` - `0x83FF_FFFF` | `3'b001` | APB Slave 0 |
| 1 | `0x8400_0000` - `0x87FF_FFFF` | `3'b010` | APB Slave 1 |
| 2 | `0x8800_0000` - `0x8BFF_FFFF` | `3'b100` | APB Slave 2 |

Addresses outside the `0x8000_0000` - `0x8C00_0000` range are not decoded by this bridge (the `valid` signal remains deasserted).

---

## FSM State Machine

The APB FSM Controller defines eight states:

| State | Encoding | Description |
|-------|----------|-------------|
| `ST_IDLE` | `3'b000` | Idle; `Hreadyout = 1`. Waits for `valid`. Transitions to `ST_WWAIT` (write) or `ST_READ` (read) |
| `ST_WWAIT` | `3'b001` | Write wait; allows `HWDATA` to arrive on the AHB bus. Transitions to `ST_WRITE` or `ST_WRITEP` |
| `ST_READ` | `3'b010` | Read setup phase; drives `PSELx`, `PADDR`, `PWRITE=0`, `PENABLE=0`. `Hreadyout = 0` (stalls AHB). Always transitions to `ST_RENABLE` |
| `ST_WRITE` | `3'b011` | Write setup phase; drives `PSELx`, `PADDR`, `PWDATA`, `PWRITE=1`, `PENABLE=0`. `Hreadyout = 0`. Transitions to `ST_WENABLE` or `ST_WENABLEP` |
| `ST_WRITEP` | `3'b100` | Pipelined write setup; handles back-to-back writes. Always transitions to `ST_WENABLEP` |
| `ST_RENABLE` | `3'b101` | Read enable phase; `PENABLE=1`, `Hreadyout=1`. Transaction completes. Can chain to next operation |
| `ST_WENABLE` | `3'b110` | Write enable phase; `PENABLE=1`, `Hreadyout=1`. Transaction completes. Can chain to next operation |
| `ST_WENABLEP` | `3'b111` | Pipelined write enable; completes current write while preparing next. Uses `Hwritereg` to decide next state |

### State Transition Overview

```
Write Path:   IDLE --> WWAIT --> WRITE --> WENABLE --> (IDLE / WWAIT / READ)
Read Path:    IDLE --> READ  --> RENABLE             --> (IDLE / WWAIT / READ)
Pipelined:    WWAIT --> WRITEP --> WENABLEP --> (WRITE / WRITEP / READ)
```

---

## Simulation and Synthesis

### Running a Simulation (ModelSIM)

1. Create a new project in ModelSIM and add all Verilog source files.
2. Compile the design files in order:
   - `AHB_Slave_Interface.v`
   - `APB_Controller.v`
   - `bridge_top.v`
3. Compile the testbench files:
   - `AHB_Master.v`
   - `APB_Interface.v`
4. Create a top-level testbench that instantiates `Bridge_Top`, `AHB_Master`, and `APB_Interface`, connecting all ports.
5. Run the simulation and observe the waveforms to verify single read and write operations.

### Running Synthesis (Quartus Prime)

1. Create a new Quartus Prime project targeting the **Cyclone V** family, device **5CSXFC6D6F31I7ES**.
2. Add the synthesizable design files:
   - `bridge_top.v`
   - `AHB_Slave_Interface.v`
   - `APB_Controller.v`
3. Set `Bridge_Top` as the top-level entity.
4. Run Analysis & Synthesis to generate the RTL netlist.
5. Use the RTL Viewer and State Machine Viewer to inspect the design.

---

## Tools and Target Device

| Item | Value |
|------|-------|
| **HDL** | Verilog |
| **Simulator** | ModelSIM |
| **Synthesis Tool** | Quartus Prime |
| **FPGA Family** | Cyclone V |
| **Device** | 5CSXFC6D6F31I7ES |

---

## Results

### Simulation

The simulation demonstrates a write operation followed by a read operation on the AHB bus, successfully mapped to the APB bus:

![Simulation Results](https://user-images.githubusercontent.com/91010702/194483573-0e104260-c1b7-4810-88fe-c9aa4a32395f.png)

### Synthesis

**RTL Model:**

![RTL Model](https://user-images.githubusercontent.com/91010702/194485990-f8ff7727-387e-42ef-8fa7-d39034216ffc.png)

**State Machine Viewer:**

![State Machine Viewer](https://user-images.githubusercontent.com/91010702/194485981-4a8f44e9-390b-4100-84b3-abe9c4930377.png)

---

## Further Work

- Add burst read and burst write operation support in the AHB Master testbench
- Implement an arbitration mechanism with arbitration signals to generalize the testbench for multi-master scenarios

---

## References

- [AMBA Modules (Chapter 4)](https://github.com/prajwalgekkouga/AHB-to-APB-Bridge/files/9731505/AMBA.Modules.pdf)
- [AMBA Specification (Chapters 1, 2, 3, and 5)](https://github.com/prajwalgekkouga/AHB-to-APB-Bridge/files/9731507/AMBA.Specifications.pdf)
- [ARM AMBA Specification (Rev 2.0)](https://web.eecs.umich.edu/~prabal/teaching/eecs373-f12/readings/ARM_AMBA3_APB.pdf)

---

## Basic Terminology

| Term | Definition |
|------|------------|
| **Bus Cycle** | A basic unit of one bus clock period, defined from rising-edge to rising-edge transitions |
| **Bus Transfer** | A read or write operation of a data object. AHB/ASB transfers may take one or more bus cycles; APB transfers always require exactly two bus cycles |
| **Burst Operation** | One or more data transactions to an incremental address region with a consistent transfer width. Not supported on the APB |
