# **AXI4-Stream Synchronous FIFO Buffer**

## **Overview**
This folder contains a highly optimized, fully synthesizable **AXI4-Stream Synchronous FIFO Buffer** implemented in SystemVerilog. This IP block acts as a bridge between an upstream AXI-Stream Master and a downstream AXI-Stream Slave, providing clock-edge handshaking, elastic buffering, and mathematically proven protocol flow control.

The design strictly adheres to the AMBA AXI4-Stream protocol specification, natively supporting packet framing boundaries (`TLAST`) and byte-level sparsity qualifiers (`TKEEP`).

## **Micro-Architectural Highlights**

### **1. Zero-Latency Combinational Flow Control**
Unlike traditional FSM-gated FIFOs that introduce clock-cycle latency penalties, this design utilizes a zero-latency combinational flow-control pipeline.
* **Backpressure (Overflow Protection):** The slave interface dynamically monitors the queue's active element count and asserts `s_axis_tready` entirely combinationally. If the internal memory gets filled up, the bus is instantly backpressured, safely blocking incoming transfers without dropping data.
* **Underflow Protection:** The master interface dynamically drops `m_axis_tvalid` the moment the queue is empty, strictly protecting downstream IP blocks from reading garbage/unallocated memory.

### **2. Dynamic Pointer Auto-Wrapping**
Internal read (`rd_ptr`) and write (`wr_ptr`) pointers are sized parametrically. By strictly sizing the pointers to the binary log of the depth, the pointers automatically wrap around at the memory boundaries via natural binary overflow, eliminating the need for complex, gate-heavy reset or modulo logic in the data path.

### **3. Parametric Scalability & Indexed Part-Selects**
The FIFO memory array is mathematically scalable. `TDATA`, `TKEEP`, and `TLAST` are concatenated into a single memory block on writes. On reads, the design utilizes SystemVerilog's **Indexed Part-Select operator (`+:`)** to dynamically calculate unpacking slice boundaries. This ensures the RTL mathematically scales to any `DATA_WIDTH` at compile-time with zero hardcoded offsets or bit-width mismatches.

### **4. Concurrent Read/Write Stability**
The internal items counter (`fifo_count`) is managed via a dedicated case-logic block mapping the concurrent states of `is_wr_event` and `is_rd_event`. If a write and read handshake occur on the exact same clock cycle, the counter flawlessly holds its state, preventing desynchronization.

## **Design Verification (DV)**
The RTL is verified using a rigorous, custom-built SystemVerilog testbench. The verification suite features active-clock-edge evaluation (avoiding infinite testbench hang-loops) and covers:
* **FIFO Sanity:** Strictly matching First-In, First-Out sequential read/write order.
* **Capacity Sweeps:** Purposefully attempting to overflow the queue to verify absolute backpressure cycle-accuracy.
* **Packet Framing Propagation:** Injecting multi-beat packets with diverse `TKEEP` byte-masks and `TLAST` end-of-frame markers, executing a real-time scoreboard check to guarantee that sideband signals propagate through the memory array and emerge perfectly synchronized with their parent payload.

## **Parameters**
| Parameter | Default | Description |
| :--- | :--- | :--- |
| `DATA_WIDTH` | `32` | Width of the `TDATA` bus in bits. Automatically scales `TKEEP` width to `DATA_WIDTH/8`. |
| `FIFO_DEPTH` | `16` | Maximum number of data beats the FIFO can store. Must be a power of 2 for auto-wrapping. |
