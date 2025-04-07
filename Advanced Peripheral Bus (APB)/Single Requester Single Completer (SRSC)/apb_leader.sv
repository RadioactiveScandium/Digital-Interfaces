// Requester for the APB subsystem which talks to a single Completer

module apb_leader #(parameter ADDR_WIDTH=10, DATA_WIDTH=16) 
                                ( 
                                      // Required inputs
                                      input  logic                  PCLK,
                                      input  logic                  PRESETN,
                                      input  logic                  transfer,
                                      input  logic                  READ_WRITE,

                                      // Driver <----> Leader
                                      //input  logic [ADDR_WIDTH-1:0] in_wr_addr,
                                      input  logic [DATA_WIDTH-1:0] in_wr_data,
                                      input  logic [ADDR_WIDTH-1:0] in_addr,
                                      output logic [DATA_WIDTH-1:0] out_rd_data,

                                      // Leader <----> Follower
                                      output logic [ADDR_WIDTH-1:0] PADDR,
                                      output logic                  PSEL,           // Dictates the SETUP phase
                                      output logic                  PWRITE,
                                      output logic [DATA_WIDTH-1:0] PWDATA,
                                      output logic                  PENABLE,        // Dictates the ACCESS phase
                                      input  logic                  PREADY,
                                      input  logic [DATA_WIDTH-1:0] PRDATA
                                );


enum logic [1:0] {IDLE,SETUP,ACCESS} state,next_state;

always_ff@(posedge PCLK or negedge PRESETN) begin
    if(~PRESETN) begin
        state <= IDLE;
    end
    else begin 
        state <= next_state;
    end
end

assign PWRITE = ~READ_WRITE;
assign PSEL = (state == IDLE) ? 1'b0 : 1'b1;
//logic  PSEL1, PSEL2;

//assign PSEL1 = (state == IDLE) ? 1'b0 : (in_addr[9] ? 1'b1 : 1'b0) ;

always_comb begin
   case (state)
      IDLE    : begin 
                    next_state = (~transfer) ? IDLE : SETUP ;
                    PENABLE = 1'b0;
                end
      SETUP   : begin
                    next_state = (~transfer) ? IDLE : ACCESS ;
                    PENABLE = 1'b0;
                    if (PWRITE) begin
                        PADDR  = in_addr;
                        PWDATA = in_wr_data;
                    end
                    else
                        PADDR  = in_addr;
                end
      ACCESS  : begin
                        PENABLE = 1'b1;
                        if(PREADY == 1'b0)
                            next_state = ACCESS;
                        else begin
                            if (~transfer) begin
                                next_state = IDLE ;
                                PENABLE = 1'b0;
                            end
                            else begin
                                next_state  = SETUP ;
                                if (~PWRITE)
                                    out_rd_data = PRDATA;
                            end    
                        end
                end
      default : next_state = IDLE;
   endcase
end


endmodule