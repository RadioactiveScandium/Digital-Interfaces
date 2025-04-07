module apb_top #(parameter ADDR_WIDTH=10, DATA_WIDTH=16, DEPTH=1024) 
                                ( 
                                      // Required inputs
                                      input  logic                  PCLK,
                                      input  logic                  PRESETN,
                                      input  logic                  transfer,
                                      input  logic                  READ_WRITE,

                                      // Driver <----> Leader
                                      input  logic [DATA_WIDTH-1:0] in_wr_data,
                                      input  logic [ADDR_WIDTH-1:0] in_addr,
                                      output logic [DATA_WIDTH-1:0] out_rd_data
                                );

                                
// Leader <----> Follower
logic [ADDR_WIDTH-1:0] PADDR;
logic                  PSEL;
logic                  PWRITE;
logic [DATA_WIDTH-1:0] PWDATA;
logic                  PENABLE;
logic                  PREADY;
logic [DATA_WIDTH-1:0] PRDATA;

apb_leader i_apb_leader( 
                           .PCLK(PCLK),
                           .PRESETN(PRESETN),
                           .transfer(transfer),

                           .in_wr_data(in_wr_data),
                           .in_addr(in_addr),
                           .out_rd_data(out_rd_data),
                           .READ_WRITE(READ_WRITE),

                           // Leader <----> Follower
                           .PADDR(PADDR),
                           .PSEL(PSEL),
                           .PWRITE(PWRITE),
                           .PWDATA(PWDATA),
                           .PENABLE(PENABLE),
                           .PREADY(PREADY),
                           .PRDATA(PRDATA)
                      );


sram_apb #(.DATA_WIDTH(16),.ADDR_WIDTH(10),.DEPTH(1024)) 
                    i_sram_apb ( 
                     .rstn(PRESETN),
                     .clk(PCLK),
                     .sel(PSEL),
                     .wr(PWRITE),  
                     .en(PENABLE),
                     .addr(PADDR),
                     .wr_data(PWDATA),
                     .rd_data(PRDATA),
                     .ready(PREADY)
                   );

endmodule