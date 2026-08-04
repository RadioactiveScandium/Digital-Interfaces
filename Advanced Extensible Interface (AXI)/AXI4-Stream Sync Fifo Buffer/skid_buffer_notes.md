# **The "First-Word Fall-Through" (FWFT) FIFO & Output Stability**

When designing high-performance AXI-Stream FIFOs, a classic timing hazard occurs at the read interface: **Output Handshake Instability**.

This document outlines why combinational read paths fail formal verification (SVAs) and how industry-standard Skid Buffers (Output Registers) solve the problem.

---

## **1. The Combinational Memory Trap**
A naive FIFO reads data combinationally directly from the memory array:
```systemverilog
// The Combinational Read
assign m_axis_tdata = sync_fifo[rd_ptr];

// The Delayed Pointer
always_ff @(posedge aclk) begin
    if (m_axis_tvalid && m_axis_tready) rd_ptr <= rd_ptr + 1;
end
```

### **Why this fails (Cycle-by-Cycle Trace):**
* **Cycle 0:** 
  * The downstream slave accepts the first word (`m_axis_tready = 1`). 
  * The handshake completes (`is_rd_event = 1`). 
  * The data `sync_fifo[0]` is correctly captured by the slave.
* **Cycle 1:** 
  * The slave decides it is busy and drops its ready signal (`m_axis_tready = 0`). 
  * Because the handshake finished in Cycle 0, the `rd_ptr` register updates on this clock edge from `0` to `1`.
  * Because `rd_ptr` changed to `1`, the combinational assignment *instantly* pushes the next word (`sync_fifo[1]`) onto the `m_axis_tdata` bus!
* **The SVA Violation:** 
  * During Cycle 1, the slave's ready signal was `0`. The AMBA AXI protocol dictates that when `tready` is `0`, the data bus *must remain completely stable*. 
  * By instantly changing the data bus to `sync_fifo[1]` while the slave was paused, the FIFO violated the AXI-Stream Handshake Stability Contract!

---

## **2. The Solution: The FWFT Output Register (Skid Buffer)**
To prevent the output bus from changing wildly when the read pointer updates, we sever the combinational link. We introduce a dedicated **Output Pipeline Register** (often called a Skid Buffer) to lock the data into place.

### **The Architecture:**
```systemverilog
// Dedicated Output Registers
logic [DATA_WIDTH-1:0] m_tdata_reg;

// The "Lock-and-Load" State Machine
always_ff @(posedge aclk or negedge aresetn) begin
    if (~aresetn) begin
        m_tdata_reg <= '0;
    end else if (m_axis_tvalid && m_axis_tready || !m_axis_tvalid) begin
        // LOAD: If the downstream slave just accepted the data (handshake), 
        // OR if the output register is completely empty (!tvalid),
        // it is safe to load the next word from the memory array.
        m_tdata_reg <= sync_fifo[rd_ptr];
    end
    // LOCK: Otherwise (if valid is 1 but ready is 0), do nothing! 
    // The register locks and preserves the old data perfectly stable.
end

// Drive the bus from the stable register
assign m_axis_tdata = m_tdata_reg;
```

### **Why this works:**
* **Cycle 0:** The slave accepts the first word (`m_axis_tready = 1`). The register is flagged to load the next word (`sync_fifo[1]`).
* **Cycle 1:** The slave drops ready (`m_axis_tready = 0`). The register loads `sync_fifo[1]` and drives it to the bus.
* **Cycle 2:** The slave keeps ready low. The `if` condition fails. The register *locks*, holding `sync_fifo[1]` perfectly stable. The SVA handshake contract is satisfied!

---

## **3. The FIFO Empty Check (The Pre-Fetch Offset)**
When you add an output register, the data is pulled out of the memory array *one cycle before* the downstream slave actually reads it. This means your read pointer (`rd_ptr`) is sitting one index ahead of what is currently on the output bus!

Because of this, **your `fifo_count` logic must account for the item sitting in the output register**.
* If `fifo_count == 1`, but that 1 item has already been fetched into the output register, the internal memory array is technically empty!
* You must ensure your `fifo_empty` and `m_axis_tvalid` flags look at whether the *output register* contains valid data, not just the raw memory array count.
