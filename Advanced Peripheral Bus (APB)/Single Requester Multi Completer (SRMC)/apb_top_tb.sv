`timescale 1ns/1ps
module apb_top_test #(parameter ADDR_WIDTH=10, DATA_WIDTH=16) (); 

logic                  PCLK;
logic                  PRESETN;
logic                  READ_WRITE;
logic                  transfer;
logic [DATA_WIDTH-1:0] in_wr_data;
logic [ADDR_WIDTH-1:0] in_addr;
logic [DATA_WIDTH-1:0] out_rd_data;

apb_top  dut( 
               .PCLK(PCLK),
               .PRESETN(PRESETN),
               .READ_WRITE(READ_WRITE),
               .transfer(transfer),
               .in_wr_data(in_wr_data),
               .in_addr(in_addr),
               .out_rd_data(out_rd_data)
            );

always #5 PCLK= ~PCLK;

initial begin
    PRESETN    = 1'b0; 
    PCLK       = 1'b0;
    READ_WRITE = 1'b0;
    transfer   = 1'b0;
    in_addr    = 10'h0;
    in_wr_data = 16'hFF; #50;
end

initial begin
  $fsdbDumpvars("+fsdbfile+apb_top_test.fsdb","+all");
  
  /* Releasing the reset */
  #50 PRESETN  = 1'b1; 
  #20 transfer = 1'b1;

  // WRITE Operation
  repeat (3) @(posedge PCLK) READ_WRITE <= 1'b0;
  repeat (3) @(posedge PCLK) in_addr <= 10'h1; in_wr_data = 16'hBB22;
  repeat (3) @(posedge PCLK) in_addr <= 10'h3FE; in_wr_data = 16'hBB33;
  repeat (3) @(posedge PCLK) in_addr <= 10'h2; in_wr_data = 16'hBB44;
  repeat (3) @(posedge PCLK) in_addr <= 10'h3FF; in_wr_data = 16'hBB55;
  //#30;
  repeat (2) @(posedge PCLK) transfer <= 1'b0;

  // READ Operation
  @(posedge PCLK) transfer <= 1'b1;
  repeat (3) @(posedge PCLK) READ_WRITE <= 1'b1;
  repeat (3) @(posedge PCLK) in_addr <= 10'h1;
  repeat (3) @(posedge PCLK) in_addr <= 10'h3FE;
  repeat (3) @(posedge PCLK) in_addr <= 10'h2;
  repeat (3) @(posedge PCLK) in_addr <= 10'h3FF;
  #30;
  repeat (2) @(posedge PCLK) transfer <= 1'b0;

  // End Of Simulation
  #20 $finish;
end


endmodule