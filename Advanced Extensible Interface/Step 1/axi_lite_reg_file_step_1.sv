////////////////////////////////////////////////////////////
/////////////  REUSABLE MACROS FOR ELEGANCE !  ////////////
///////////////////////////////////////////////////////////
`define ASYNC_RESET_EN_FF(q, d, en, clk, rst_n) \
always_ff @(posedge clk or negedge rst_n) begin \
    if (!rst_n) q <= '0; \
    else  if(en)      q <= d; \
    else              q <= q; \   
end

`define ASYNC_RESET_FF(q, d, clk, rst_n) \
always_ff @(posedge clk or negedge rst_n) begin \
    if (!rst_n) q <= '0; \
    else        q <= d; \   
end


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module name : axi_lite_reg_file
//
// Description : 
//
// The axi_lite_reg_file is an AXI4-Lite compliant slave IP containing four 32-bit registers with diverse access policies. 
// It handles byte-level write masking via strobe signals, detects alignment/out-of-range addressing faults, and returns 
// standard protocol error responses.
//
// Author : Saransh Choudhary
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
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
logic [31:0]      reg_bank0;
logic [31:0]      reg_bank1;

// Writing to the registers if : 
//    1. State is IDLE 
//    2. All handshakes are done
`ASYNC_RESET_EN_FF(reg_bank0, s_axi_wdata, ((state == IDLE) && aw_hs_done_reg && w_hs_done_reg), aclk, aresetn)
`ASYNC_RESET_EN_FF(reg_bank1, s_axi_wdata, ((state == IDLE) && aw_hs_done_reg && w_hs_done_reg), aclk, aresetn)

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

            // 2. Check if the write response ready from master side is available
            //    If so, this means that the B channel handshake is complete and 
            //    the FSM can move back to IDLE state for the next transfer
            if (s_axi_bready)
                next_state = IDLE;

        end

    endcase

end : WRITE_STATE_FSM

endmodule
