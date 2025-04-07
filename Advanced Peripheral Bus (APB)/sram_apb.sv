// Completer for the APB subsystem

module sram_apb #( 
                   parameter int DATA_WIDTH = 16,
                   parameter int ADDR_WIDTH = 10,
                   parameter int DEPTH = 8 
                 ) 
                 ( 
                     input  logic                     rstn,    // connect to PRESETn 
                     input  logic                     clk,     // connect to PCLK
                     input  logic                     sel,     // connect to PSEL 
                     input  logic                     wr,      // connect to PWRITE  
                     input  logic                     en,      // connect to PENABLE
                     input  logic [ADDR_WIDTH-1:0]    addr,    // connect to PADDR
                     input  logic [DATA_WIDTH-1:0]    wr_data, // connect to PWDATA
                     output logic [DATA_WIDTH-1:0]    rd_data, // connect to PRDATA
                     output logic                     ready    // connect to PREADY
                 );

logic [DEPTH-1:0][DATA_WIDTH-1:0] sram;

// In the spec, the PREADY is a single cycle signal in ideal condition (no wait states), but in the sim it is
// 2 cycles - it is because of the memory coded in seq logic
always_ff@(posedge clk or negedge rstn) begin
    if(~rstn) begin
        {sram,rd_data} <= {0,{DATA_WIDTH{1'h0}}};
        ready <= 1'b0;
    end
    else begin
        if(sel) begin
          case({wr,en})
              2'b00 :   begin 
                            sram[addr] <= sram[addr];  // No Operation
                            ready <= 1'b0;
                        end
              2'b01 :   begin
                            ready  <= 1'b1;
                            rd_data <= sram[addr];    // Read Operation
                        end
              2'b10 :   begin
                            sram[addr] <= sram[addr]; // No Operation
                            ready <= 1'b0;
                        end
              2'b11 :   begin
                            sram[addr] <= wr_data;    // Write Operation
                            ready <= 1'b1;
                        end
              default : sram[addr] <= sram[addr];    // No Operation
          endcase
        end
        else begin
              sram[addr] <= sram[addr];
              ready <= 1'b0;
        end
    end
end

endmodule