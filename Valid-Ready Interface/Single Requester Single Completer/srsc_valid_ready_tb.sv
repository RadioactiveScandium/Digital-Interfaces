`timescale 1ns/1ps
module srsc_valid_ready_test();

logic              rstn;
logic              clk;
logic              valid_top;
logic [`DSIZE-1:0] data_sent_top;
logic [`DSIZE-1:0] data_rcvd_top;

valid_ready valid_ready ( .* );

always #5 clk = ~clk;

initial begin
    rstn = 1'b0;
    clk = 1'b0;
    valid_top = 1'b0;
    data_sent_top = 4'b0;
end

initial begin
    $fsdbDumpvars("+fsdbfile+srsc_valid_ready.fsdb","+all");
    #10; rstn = 1'b1; #20;
    @(posedge clk) {valid_top,data_sent_top} = {1'b0,4'hA};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'hB};
    @(posedge clk) {valid_top,data_sent_top} = {1'b0,4'hC};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'hD};
    @(posedge clk) {valid_top,data_sent_top} = {1'b0,4'hE};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'h9};
    // B2B transactions start
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'h8};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'h7};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'h6};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'h5};
    // B2B transactions end
    @(posedge clk) {valid_top,data_sent_top} = {1'b0,4'h4};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'h3};
    @(posedge clk) {valid_top,data_sent_top} = {1'b0,4'h2};
    @(posedge clk) {valid_top,data_sent_top} = {1'b1,4'h1};
    #30;
    $finish;
end

initial begin
   $display("*************************************************** RESULTS **********************************************");
   $display("******* Primary input to primary output is a two clock cycle long path *************");
   $monitor("Injected Data : %h\t\tTransferred Data : %h\t\tReady : %b\t\tTop level valid : %b",data_sent_top,data_rcvd_top,srsc_valid_ready_test.valid_ready.ready,valid_top);
end

endmodule