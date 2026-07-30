////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module name : axi_lite_reg_file
//
// Description : 
//
// The axi_lite_reg_file is an AXI4-Lite compliant slave IP containing four 32-bit registers with diverse access policies. 
// It handles byte-level write masking via strobe signals, detects alignment/out-of-range addressing faults, and returns 
// standard protocol error responses.
//
// Deltas w.r.t Step 3 :
//   1. Support for fault condition detection (address out of bounds and 4-byte alignment) with Start and End Addresses
//      -> This is done for both AW and AR as the two channels are independent
//   2. Blocking the write access if violated and issue a DECERR back to master, else send OKAY 
//   3. Broadcast garbage value for read access if violated and issue a DECERR back to master, else send OKAY 
//   4. Added some key System Verilog Assertions 
//
// Author : Saransh Choudhary
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
`include "common/ff_macros.svh"
module axi_lite_reg_file #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 12
)(
    // Global Signals
    input  logic                                 aclk,
    input  logic                                 aresetn,

    // Write Address Channel (AW)
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_awaddr,
    input  logic                                 s_axi_awvalid,
    output logic                                 s_axi_awready,

    // Write Data Channel (W)
    input  logic [C_S_AXI_DATA_WIDTH-1:0]        s_axi_wdata,
    input  logic [(C_S_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb,
    input  logic                                 s_axi_wvalid,
    output logic                                 s_axi_wready,

    // Write Response Channel (B)
    output logic [1:0]                           s_axi_bresp,
    output logic                                 s_axi_bvalid,
    input  logic                                 s_axi_bready,

    // Read Address Channel (AR)
    input  logic [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_araddr,
    input  logic                                 s_axi_arvalid,
    output logic                                 s_axi_arready,

    // Read Data Channel (R)
    output logic [C_S_AXI_DATA_WIDTH-1:0]        s_axi_rdata,
    output logic [1:0]                           s_axi_rresp,
    output logic                                 s_axi_rvalid,
    input  logic                                 s_axi_rready,

    // Non-AXI Sideband Hardware Interface
    input  logic [31:0]                          hw_status_in
);

enum logic [1:0] {IDLE, B_RESP} state, next_state;

////////////////////////////////////////////////////////////
///////////// HANDSHAKE CONDITIONS FOR WRITE  /////////////
///////////////////////////////////////////////////////////
logic             aw_hs_done;
logic             aw_hs_done_next;
logic             aw_hs_done_reg;
logic             w_hs_done;
logic             w_hs_done_next;
logic             w_hs_done_reg;

// Single cycle pulse to denote the handshaking is complete
assign aw_hs_done = s_axi_awvalid && s_axi_awready;
assign w_hs_done  = s_axi_wvalid  && s_axi_wready;

// Defining conditions when to set/clear the sticky registers
// (Set on handshake, clear when transaction is acknowledged by entering B_RESP)
assign aw_hs_done_next = (state == B_RESP) ? 1'b0 : (aw_hs_done ? 1'b1 : aw_hs_done_reg);
assign w_hs_done_next  = (state == B_RESP) ? 1'b0 : (w_hs_done  ? 1'b1 : w_hs_done_reg);

// Sticky registers (flip-flops) to "remember" that a channel has successfully handshaked, and clear them when 
// entering B_RESP state
`ASYNC_RESET_FF(aw_hs_done_reg, aw_hs_done_next, aclk, aresetn)
`ASYNC_RESET_FF(w_hs_done_reg,  w_hs_done_next,  aclk, aresetn)

////////////////////////////////////////////////////////////
/////////////////   REGISTER WRITES     ///////////////////
///////////////////////////////////////////////////////////
logic [C_S_AXI_DATA_WIDTH-1:0]       reg_bank0;
logic [C_S_AXI_DATA_WIDTH-1:0]       reg_bank1;
logic                              reg_bank0_w_addr_match;
logic                              reg_bank1_w_addr_match;
logic [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr_reg;
logic [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb_reg;

// Registering the address/strobe to avoid address slippage
//
// Writing to the registers when the adress and data arrive at the same time is not a problem at all. 
// The top level address s_axi_awaddr can be compared against the address map combinationally to 
// perform address matching and use it as a qualifier to write to the registers.
//
// However, if the awvalid arrives ahead of wvalid, then this causes an issue :
// 
// 1. The awvalid and awready arrive ahead of wvalid, causing AW channel handshake completion
// 2. Since the handshake is complete, the master correctly deasserts awvalid to 0 and drives 
//    a garbage value 12'hXXX on the address line
// 3. Now if the address matching is done on raw awaddr, the combo logic sees 12'hXXX on the 
//    awaddr line and the expression (say reg_bank1_addr_match) resolves to zero
// 4. Since the condition in (3) resolves to 0, the write enable to the flops becomes zero
// 5. As a result, the write transfer on the register is dropped 
`ASYNC_RESET_EN_FF(s_axi_awaddr_reg, s_axi_awaddr, aw_hs_done, aclk, aresetn)
`ASYNC_RESET_EN_FF(s_axi_wstrb_reg,  s_axi_wstrb,  w_hs_done,  aclk, aresetn)

// Why aw_hs_done cannot be used as an enable while flopping awaddr/wstrb
// aw_hs_done_reg is only a 1-bit flag. It successfully remembers that an address handshake happened. 
//    * But it does not remember what address was requested. It has no memory of the 12-bit address bits (s_axi_awaddr).
//    * When the address handshake completes, the master immediately changes the external address bus lines (s_axi_awaddr) to garbage (12'hXXX).
//    * So, when the write data finally handshakes 3 cycles later:
//      * Your 1-bit flag aw_hs_done_reg is correctly sitting at 1 (it remembers that an address arrived).
//      * But when your write-enable logic tries to verify which register to write to, it looks at the external address bus (s_axi_awaddr), which is currently garbage. 
//      * Because the external bus has garbage, your address-match logic fails, and the write is blocked!

// Matching the address for each reg bank using flopped address
assign reg_bank0_w_addr_match = (s_axi_awaddr_reg == 12'h000);
assign reg_bank1_w_addr_match = (s_axi_awaddr_reg == 12'h004);


////////////////////////////////////////////////////////////
/////////////     WRITE ADDRESS FAULT CHECK    /////////////
///////////////////////////////////////////////////////////
logic w_addr_in_range;
logic w_addr_alignment;
logic w_addr_fault;

assign w_addr_in_range  = ( s_axi_awaddr_reg >= 12'h000 && s_axi_awaddr_reg <= 12'h00C);
assign w_addr_alignment = ( s_axi_awaddr_reg[1:0] == 2'b00);
assign w_addr_fault     = ~w_addr_alignment || ~w_addr_in_range;

// Writing to the registers if (also strobes, captured later in the actual flop statement) : 
//    1. State is IDLE 
//    2. All handshakes are done
//    3. Address Matches 
//    4. Address is free of faults
logic reg_bank0_wr_en;
logic reg_bank1_wr_en;
assign reg_bank0_wr_en = ((state == IDLE) && (aw_hs_done_reg && w_hs_done_reg) && reg_bank0_w_addr_match && ~w_addr_fault); 
assign reg_bank1_wr_en = ((state == IDLE) && (aw_hs_done_reg && w_hs_done_reg) && reg_bank1_w_addr_match && ~w_addr_fault);

////////////////////////////////////////////////////////////
/////////////     ACTUAL REGISTER WRITES      /////////////
///////////////////////////////////////////////////////////
always_ff @(posedge aclk or negedge aresetn) begin : REG0_WRITE
    if (~aresetn) begin
        reg_bank0 <= '0;
    end else if (reg_bank0_wr_en) begin
        // Loop through the 4 byte lanes (0 to 3)
        for (int i = 0; i < 4; i++) begin
            if (s_axi_wstrb_reg[i]) begin
                // The "+:" indexed part-select operator targets exactly 8 bits starting at (i * 8)
                reg_bank0[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
            end
        end
    end
end

always_ff @(posedge aclk or negedge aresetn) begin : REG1_WRITE
    if (~aresetn) begin
        reg_bank1 <= '0;
    end else if (reg_bank1_wr_en) begin
        // Loop through the 4 byte lanes (0 to 3)
        for (int i = 0; i < 4; i++) begin
            if (s_axi_wstrb_reg[i]) begin
                // The "+:" indexed part-select operator targets exactly 8 bits starting at (i * 8)
                reg_bank1[i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
            end
        end
    end
end

////////////////////////////////////////////////////////////
/////////////////   WRITE FSM ENGINE    ///////////////////
///////////////////////////////////////////////////////////

// State transition flop
always_ff @(posedge aclk or negedge aresetn) begin
    if (~aresetn) state <= IDLE;
    else        state <= next_state;
end

always_comb begin : WRITE_STATE_FSM
   // DEFAULT VALUES (Avoids Latch Inference)
        next_state    = state;
        s_axi_awready = 1'b0;
        s_axi_wready  = 1'b0;
        s_axi_bvalid  = 1'b0;
        s_axi_bresp   = 2'b00; // Always assign responses
        
    case(state)

        IDLE : begin

            // 1. Set the READY signals to high for receiving data immediately
            {s_axi_awready, s_axi_wready} = {1'b1, 1'b1};

            // 2. Check for the handshake of AW and W channels - if it is complete,
            //    de-assert ready and transit to B_RESP state ; note that data 
            //    gets written to registers in separate parallel FF blocks and
            //    the write happens in the IDLE state
            if (aw_hs_done_reg && w_hs_done_reg) begin
                {s_axi_awready, s_axi_wready} = {1'b0, 1'b0};
                next_state = B_RESP;
            end

        end

        B_RESP : begin

            // 1. Set the write response valid signal to high
            s_axi_bvalid = 1'b1;

            // 2. Issue a DECERR to master if the write is blocked
            if (w_addr_fault) 
                s_axi_bresp = 2'b11;
            else              
                s_axi_bresp = 2'b00;

            // 3. Check if the write response ready from master side is available
            //    If so, this means that the B channel handshake is complete and 
            //    the FSM can move back to IDLE state for the next transfer
            if (s_axi_bready)
                next_state = IDLE;

        end

    endcase

end : WRITE_STATE_FSM


enum logic [1:0] {READ_IDLE, READ_DATA} state_for_read, next_state_for_read ;

////////////////////////////////////////////////////////////
/////////////  HANDSHAKE CONDITIONS FOR READ   ////////////
///////////////////////////////////////////////////////////
logic             r_hs_done;
logic             r_hs_done_next;
logic             r_hs_done_reg;
logic             ar_hs_done;
logic             ar_hs_done_next;
logic             ar_hs_done_reg;

// Since reg_bank2 at 12'h008 is write-only, reads must return 0. This code already handles this perfectly 
// by falling through to the default '0 value!
logic             reg_bank0_r_addr_match;
logic             reg_bank1_r_addr_match;
logic             reg_bank3_r_addr_match;

// Single cycle pulse to denote the handshaking is complete
assign r_hs_done   = s_axi_rvalid  && s_axi_rready;
assign ar_hs_done  = s_axi_arvalid && s_axi_arready;

// Defining conditions when to set/clear the sticky registers
// (Set on handshake, clear when transaction is acknowledged by entering READ_DATA)
assign r_hs_done_next   = (state_for_read == READ_DATA) ? 1'b0 : (r_hs_done   ? 1'b1 : r_hs_done_reg);
assign ar_hs_done_next  = (state_for_read == READ_DATA) ? 1'b0 : (ar_hs_done  ? 1'b1 : ar_hs_done_reg);

// Sticky registers (flip-flops) to "remember" that a channel has successfully handshaked, and clear them when 
// entering READ_DATA state
`ASYNC_RESET_FF(r_hs_done_reg,  r_hs_done_next,  aclk, aresetn)
`ASYNC_RESET_FF(ar_hs_done_reg, ar_hs_done_next, aclk, aresetn)

// Registering the address to avoid address slippage
logic [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr_reg;
`ASYNC_RESET_EN_FF(s_axi_araddr_reg, s_axi_araddr,  ar_hs_done, aclk, aresetn)

// Address matching for reads : REG2 (0x008) is Write-Only
assign reg_bank0_r_addr_match = (s_axi_araddr_reg == 12'h000);
assign reg_bank1_r_addr_match = (s_axi_araddr_reg == 12'h004);
assign reg_bank3_r_addr_match = (s_axi_araddr_reg == 12'h00C);

////////////////////////////////////////////////////////////
/////////////     READ ADDRESS FAULT CHECK    /////////////
///////////////////////////////////////////////////////////
logic r_addr_in_range;
logic r_addr_alignment;
logic r_addr_fault;

assign r_addr_in_range  = ( s_axi_araddr_reg >= 12'h000 && s_axi_araddr_reg <= 12'h00C);
assign r_addr_alignment = ( s_axi_araddr_reg[1:0] == 2'b00);
assign r_addr_fault     = ~r_addr_alignment || ~r_addr_in_range;

// Retrieving Data from registers and holding in temporary variable
logic [C_S_AXI_DATA_WIDTH-1:0]       r_data_from_reg;
assign r_data_from_reg  = reg_bank0_r_addr_match ? reg_bank0 : (reg_bank1_r_addr_match ? reg_bank1 : (reg_bank3_r_addr_match ? hw_status_in : 32'h0));

////////////////////////////////////////////////////////////
/////////////////   READ FSM ENGINE    ///////////////////
///////////////////////////////////////////////////////////

// State transition flop
always_ff @(posedge aclk or negedge aresetn) begin
    if (~aresetn) state_for_read <= READ_IDLE;
    else        state_for_read <= next_state_for_read;
end

always_comb begin : READ_STATE_FSM
   // DEFAULT VALUES (Avoids Latch Inference)
        next_state_for_read  = state_for_read;
        s_axi_rdata          = '0;
        s_axi_rresp          = 2'b00;
        s_axi_rvalid         = 1'b0;
        s_axi_arready        = 1'b0;
        
    case(state_for_read)

        // Check if AR channel handshake is complete ; if so, the slave is ready to receive a new read 
        // address and moves on to the next state
        READ_IDLE : begin
            s_axi_arready = 1'b1;
            if (ar_hs_done_reg) begin
                next_state_for_read = READ_DATA;
            end
        end

        // Mapping the data read from register to actual read data bus if there is no read address fault 
        // Also, sending the response (DECERR or OKAY) based on whether or not the read address is faulty
        READ_DATA : begin
            s_axi_rdata  = ~r_addr_fault ? r_data_from_reg : 32'h0;
            s_axi_rresp  = ~r_addr_fault ? 2'b00 : 2'b11;
            s_axi_rvalid = 1'b1;
            if (s_axi_rready) begin
                next_state_for_read = READ_IDLE;
            end

        end

    endcase

end : READ_STATE_FSM

//========================================================================================================
//                                   SYSTEMVERILOG ASSERTIONS (SVA)
//========================================================================================================

`ifdef ASSERT_ON

// Property 1: Write Response Handshake Stability
// Once s_axi_bvalid is asserted high, it must remain high and s_axi_bresp must remain stable (unchanged)
// until the master asserts s_axi_bready to complete the handshake.
property p_write_response_stability;
    @(posedge aclk) disable iff (!aresetn)
    (s_axi_bvalid && !s_axi_bready) |=> (s_axi_bvalid && $stable(s_axi_bresp));
endproperty

assert_write_response_stability: assert property (p_write_response_stability)
    else $error("[SVA ERROR] Write Response Handshake Stability Violated! s_axi_bvalid dropped or s_axi_bresp changed value before handshake.");

cover_write_response_stability: cover property (p_write_response_stability);

// Property 2: Read Response Handshake Stability
// Once s_axi_rvalid goes high, it must remain high and s_axi_rdata/s_axi_rresp must remain stable until 
// master asserts s_axi_rready to complete the handshake
property p_read_response_stability;
    @(posedge aclk) disable iff (!aresetn)
    (s_axi_rvalid && !s_axi_rready) |=> (s_axi_rvalid && $stable(s_axi_rdata) && $stable(s_axi_rresp));
endproperty

assert_read_response_stability: assert property (p_read_response_stability)
    else $error("[SVA ERROR] Read Response Handshake Stability Violated! s_axi_rvalid dropped or s_axi_rresp changed value before handshake.");

cover_read_response_stability: cover property (p_read_response_stability);

// Property 3: Write fault invalidation
// Any illegal write address strictly results in a DECERR write response
// The trigger condition is qualified with bvalid to make sure it is checked
// during only active response phase and bvalid asserted high denotes an
// active write response phase.
property p_write_fault_invalidation;
    @(posedge aclk) disable iff (!aresetn)
    (s_axi_bvalid && w_addr_fault) |-> (s_axi_bresp == 2'b11);
endproperty

assert_write_fault_invalidation: assert property (p_write_fault_invalidation)
    else $error("[SVA ERROR] Write fault invalidation violated! The slave did not return DECERR (value of 2'b11) on s_axi_bresp signal.");

cover_write_fault_invalidation: cover property (p_write_fault_invalidation);

// Property 4: Read fault invalidation
// Any illegal read address strictly results in a DECERR write response
// The trigger condition is qualified with rvalid to make sure it is checked
// during only active response phase and rvalid asserted high denotes an
// active read response phase.
property p_read_fault_invalidation;
    @(posedge aclk) disable iff (!aresetn)
    (s_axi_rvalid && r_addr_fault) |-> (s_axi_rresp == 2'b11);
endproperty

assert_read_fault_invalidation: assert property (p_read_fault_invalidation)
    else $error("[SVA ERROR] Read fault invalidation violated! The slave did not return DECERR (value of 2'b11) on s_axi_bresp signal.");

cover_read_fault_invalidation: cover property (p_read_fault_invalidation);

`endif
    
endmodule
