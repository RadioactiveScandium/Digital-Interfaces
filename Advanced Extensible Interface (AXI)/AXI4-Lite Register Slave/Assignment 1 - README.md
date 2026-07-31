# **AXI4-Lite Register File Slave**

## **Overview**
This folder contains a highly robust, fully synthesizable **AXI4-Lite Register File Slave** implemented in SystemVerilog. Designed for strict adherence to the AMBA AXI4-Lite protocol, this IP block provides a decoupled read/write configuration interface containing four 32-bit registers with diverse access policies.

The design natively handles independent (de-phased) channel arrivals, byte-level write strobes (`WSTRB`), rigorous address fault-isolation, and protocol-compliant `DECERR` dynamic signaling.

## **Micro-Architectural Highlights**

### **1. Decoupled Read/Write State Machines**
The write and read paths are implemented using clean, independent 2-state Moore FSMs (`IDLE` and `B_RESP` / `READ_DATA`). 
* **Write Channel Independence:** The AXI protocol permits the Write Address (`AW`) and Write Data (`W`) channels to arrive independently or out-of-phase. This design captures independent channel handshakes using sequential "sticky" flip-flops (`aw_hs_done_reg` / `w_hs_done_reg`), completely preventing state-machine lockups if data is delayed by the upstream master.

### **2. Write-Address Slippage Prevention**
To prevent data loss caused by "Address-Slippage" (where a master drives garbage on the `AWADDR` lines after the address handshake completes but before the data arrives), the design captures and locks the target address into an internal stable register (`s_axi_awaddr_reg`). This guarantees perfect address matching when the delayed write data is finally committed.

### **3. Byte-Level Strobe Masking (`WSTRB`)**
The register array incorporates an unrolled, parameterized `for`-loop combined with SystemVerilog's **Indexed Part-Select operator (`+:`)** to dynamically apply the 4-bit `s_axi_wstrb` mask. This allows masters to perform fine-grained, byte-level updates to the configuration registers without corrupting adjacent unwritten bytes.

### **4. Fault Protection & DECERR Signaling**
The IP features dedicated fault-isolation networks on both the read and write paths.
* **Alignment & Range Audits:** Every transaction is dynamically verified to ensure it is 32-bit aligned (`addr[1:0] == 2'b00`) and within the legal boundary offsets (`0x000` to `0x00C`).
* **Fault Handling:** Illegal accesses are strictly blocked from corrupting internal registers. Instead, the slave actively completes the handshake while dynamically driving **`2'b11` (`DECERR`)** onto the `s_axi_bresp` (writes) and `s_axi_rresp` (reads) buses.

### **5. Diverse Register Access Policies**
The internal memory map is routed to support complex CPU access privileges:
* `REG0` & `REG1`: Full Read/Write (`R/W`) configuration registers.
* `REG2`: **Write-Only** (Reads safely return `32'h0000_0000`).
* `REG3`: **Read-Only** (Writes are ignored; Reads dynamically return the live value of a sideband `hw_status_in` pin).

## **Design Verification & SystemVerilog Assertions (SVA)**
The RTL is verified using a rigorous, self-checking SystemVerilog testbench alongside concurrent, formal **SystemVerilog Assertions (SVAs)**.
* **SVA Handshake Stability:** Formal assertions (`$stable`) mathematically guarantee that `VALID` signals and payload data do not drop or glitch prematurely once asserted.
* **SVA Fault Invalidation:** Formal properties prove that any out-of-bounds address strictly triggers a `DECERR` output state.
* **Dynamic Simulation:** The testbench injects co-phased writes, de-phased writes with garbage-address delays, unaligned accesses, partial byte-strobe masks, and boundary violations, comparing physical results against an internal behavioral Golden Reference Model.

## **Parameters**
| Parameter | Default | Description |
| :--- | :--- | :--- |
| `C_S_AXI_DATA_WIDTH` | `32` | Width of the AXI-Lite Data bus in bits (AXI4-Lite supports 32 or 64). |
| `C_S_AXI_ADDR_WIDTH` | `12` | Width of the AXI-Lite Address bus in bits. |

