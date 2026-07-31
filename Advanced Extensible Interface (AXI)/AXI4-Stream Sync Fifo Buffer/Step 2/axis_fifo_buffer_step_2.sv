////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module name : axis_fifo_buffer
//
// Description : 
//
// The axis_fifo_buffer is a synchronous FIFO that bridges an input AXI-Stream master (writing to our slave port) to an 
// output AXI-Stream slave (reading from our master port). It handles clock-edge handshaking, maintains internal 
// write/read pointers, and asserts backpressure (using tready) to prevent buffer overflows or underflows.
//
// Deltas w.r.t step_1 :
//
//   1. Added support for TLAST and TKEEP features and appended it to the payload for forming the complete frame
//   2. This required memory to be expanded
//
// Author : Saransh Choudhary
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
module axis_fifo_buffer #(
    parameter integer DATA_WIDTH = 32,
    parameter integer FIFO_DEPTH = 16
)(
    // Global Signals
    input  logic                     aclk,
    input  logic                     aresetn,

    // Slave AXI-Stream Port (Input Write Port)
    input  logic [DATA_WIDTH-1:0]       s_axis_tdata,
    input  logic [(DATA_WIDTH/8)-1:0]   s_axis_tkeep,
    input  logic                        s_axis_tlast,
    input  logic                        s_axis_tvalid,
    output logic                        s_axis_tready,

    // Master AXI-Stream Port (Output Read Port)
    output logic [DATA_WIDTH-1:0]       m_axis_tdata,
    output logic [(DATA_WIDTH/8)-1:0]   m_axis_tkeep,
    output logic                        m_axis_tlast,
    output logic                        m_axis_tvalid,
    input  logic                        m_axis_tready
);

// FIFO related internal wires
logic [($clog2(FIFO_DEPTH)-1) : 0]     wr_ptr;
logic [($clog2(FIFO_DEPTH)-1) : 0]     rd_ptr;
logic                                  fifo_full;
logic                                  fifo_empty;
logic [$clog2(FIFO_DEPTH) : 0]         fifo_count;

// Actual FIFO memory
logic [FIFO_DEPTH-1:0][(DATA_WIDTH + (DATA_WIDTH/8)):0] sync_fifo;

// Checking for the kind of transfer : whether write or read
logic                                  is_wr_event;
logic                                  is_rd_event;

assign is_wr_event = s_axis_tvalid && s_axis_tready;
assign is_rd_event = m_axis_tvalid && m_axis_tready;

// Keeps track of the number of valid data items in the FIFO at any given point of time
always_ff @(posedge aclk or negedge aresetn) begin: FIFO_ITEMS_COUNTER
     if (~aresetn)
         fifo_count <= '0;
     else begin
         case({is_wr_event,is_rd_event})
             2'b00   : fifo_count <= fifo_count;
             2'b10   : fifo_count <= fifo_count + 1;
             2'b01   : fifo_count <= fifo_count - 1;
             2'b11   : fifo_count <= fifo_count;
             default : fifo_count <= fifo_count;
         endcase
     end
end : FIFO_ITEMS_COUNTER

// Evaluating FIFO Full and Empty conditions
assign fifo_full  = (fifo_count == FIFO_DEPTH);
assign fifo_empty = (fifo_count == 0);

/////////////////////////////////////////////////////////////////////////////
////////////////////////   WRITE HANDLING  //////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

// FIFO's way of telling the system it has no futher space to accommodate 
// new data
assign s_axis_tready = ~fifo_full;

// SRAM memory arrays do not have resets. When the chip powers up, the values 
// inside the memory cells start as random junk. This is perfectly normal! 
// As long as the fifo_count logic is correct, the empty flag fifo_empty will 
// prevent the CPU from ever reading that junk
always_ff @(posedge aclk) begin : FIFO_WRITE
    if (is_wr_event) begin
        sync_fifo[wr_ptr] <= {s_axis_tdata, s_axis_tkeep, s_axis_tlast};
    end
end : FIFO_WRITE

always_ff @(posedge aclk or negedge aresetn) begin : WR_PTR
    if (~aresetn)
        wr_ptr <= '0;
    else
        wr_ptr <= is_wr_event ? wr_ptr + 1 : wr_ptr ;
end : WR_PTR

/////////////////////////////////////////////////////////////////////////////
////////////////////////   READ HANDLING  ///////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

// FIFO's way of telling the system it has no remaining data to send across 
assign m_axis_tvalid = ~fifo_empty;

// tdata translates to 36:5 for 32-bit data, tkeep to 4:1
// tdata translates to 64:9 for 64-bit data, tkeep to 8:1
assign m_axis_tdata = sync_fifo[rd_ptr][((DATA_WIDTH/8)+1) +: DATA_WIDTH]; 
assign m_axis_tkeep = sync_fifo[rd_ptr][1 +: (DATA_WIDTH/8)]; 
assign m_axis_tlast = sync_fifo[rd_ptr][0]; 

always_ff @(posedge aclk or negedge aresetn) begin : RD_PTR
    if (~aresetn)
        rd_ptr <= '0;
    else
        rd_ptr <= is_rd_event ? rd_ptr + 1 : rd_ptr ;
end : RD_PTR

endmodule
