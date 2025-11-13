module valid_ready (
                      input  logic              rstn,
                      input  logic              clk,
                      input  logic              valid_top,
                      input  logic [`DSIZE-1:0] data_sent_top,
                      output logic [`DSIZE-1:0] data_rcvd_top
                   );

logic               valid_to_completer;
logic [`DSIZE-1:0]  data_to_completer;
logic               ready;

valid_ready_requester i_driver(
                                       .rstn(rstn),
                                       .clk(clk),
                                       .ready(ready),
                                       .valid_in(valid_top),
                                       .data_in(data_sent_top),
                                       .valid_out(valid_to_completer),
                                       .data_sent(data_to_completer)
                              );

valid_ready_completer i_consumer (
                                          .rstn(rstn),
                                          .clk(clk),
                                          .valid(valid_to_completer),
                                          .data_in(data_to_completer),
                                          .ready(ready),
                                          .data_rcvd(data_rcvd_top)
                                 );
 
endmodule

module valid_ready_requester (
                               input  logic              rstn,
                               input  logic              clk,
                               input  logic              ready,
                               input  logic              valid_in,
                               input  logic [`DSIZE-1:0] data_in,
                               output logic              valid_out,
                               output logic [`DSIZE-1:0] data_sent
                             );

/* If requestor and completer are in asynchronous clock domains, ready must be synchronized to the requester clock domain and then used (valid based synchronization) */
/* Only flopping the valid is sufficient and data can be a feedthrough */
always_ff @ (posedge clk or negedge rstn) begin : REQUESTER
      if (~rstn)
         {valid_out,data_sent} <= {1'b0,`DSIZE'b0}; // the macro DSIZE comes from the package
      else begin
         if (ready) // if Rx is ready, send new data 
             {valid_out,data_sent} <= {valid_in,data_in};
         else begin 
             // stalled
             if (valid_out)
                     {valid_out,data_sent} <= {valid_out,data_sent};
             else
             // not valid and stalled - remain idle
                     {valid_out,data_sent} <= {1'b0,`DSIZE'b0};
         end
      end
end : REQUESTER

endmodule


module valid_ready_completer (
                               input  logic              rstn,
                               input  logic              clk,
                               input  logic              valid,
                               input  logic [`DSIZE-1:0] data_in,
                               output logic              ready,
                               output logic [`DSIZE-1:0] data_rcvd
                             );

/* If requestor and completer are in asynchronous clock domains, valid must be synchronized to the completer clock domain and then used (valid based synchronization) */

always_ff @ (posedge clk or negedge rstn) begin : COMPLETER
      if (~rstn)
         {data_rcvd,ready} <= {`DSIZE'b0,1'b0};
      else begin
         if (~valid)
            {data_rcvd,ready} <= {`DSIZE'b0,1'b1};
         else begin 
            // This implementation assumes the completer can always consume or store the data_rcvd on the next cycle. In a real-world design, the ready signal 
            // would be driven by the status of a of a downstream buffer or pipeline (e.g., assign ready = !downstream_buffer_full;). For this standalone module, 
            // however, assuming it's always ready is the standard way to model a high-performance sink.
            if(ready)
                  {data_rcvd,ready} <= {data_in,1'b1};   // this line is important - it is the logic which ensures that the Rx honors back-to-back transactions
                                                         // on the other hand, if ready is deasserted in this condition, then the design is still functionally correct,
                                                         // but theres's a perf penalty : maximum throughput of one transaction every two clock cycles, 
                                                         // wasting significant bandwidth
            else
                  {data_rcvd,ready} <= {data_rcvd,ready};
         end
      end
end : COMPLETER

endmodule