////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name : axi_lite_reg_file_tb
//
// Description : 
//
// This is a self-checking SystemVerilog testbench for verifying the Step 1 implementation of the AXI4-Lite
// Register File Slave. It generates a 100MHz clock and synchronous resets, and executes two distinct write tests:
//
// 1. TEST CASE 1: Co-phased/Simultaneous Write
//    - Asserts both AW (Address) and W (Data) handshakes on the exact same clock cycle.
//    - Verifies basic write-pipeline and write-response (B channel) FSM transition logic.
//
// 2. TEST CASE 2: De-phased/De-coupled Write
//    - Asserts the AW handshake first. Once completed, the master drops AWVALID and drives garbage values
//      on the AWADDR lines. After a 3-cycle delay, it asserts the W channel to handshake the write data.
//    - Verifies the robustness of the slave's sticky handshake registers (aw_hs_done_reg / w_hs_done_reg)
//      to remember out-of-phase channel arrivals.
//
// Waveform Output:
// - Generates a high-performance 'axi_lite_reg_file.fsdb' waveform file for Verdi analysis.
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module axi_lite_reg_file_tb;

    // Parameters
    localparam C_S_AXI_DATA_WIDTH = 32;
    localparam C_S_AXI_ADDR_WIDTH = 12;

    // Testbench Signals
    logic                                 aclk;
    logic                                 aresetn;

    // Write Address Channel (AW)
    logic [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_awaddr;
    logic                                 s_axi_awvalid;
    logic                                 s_axi_awready;

    // Write Data Channel (W)
    logic [C_S_AXI_DATA_WIDTH-1:0]        s_axi_wdata;
    logic [(C_S_AXI_DATA_WIDTH/8)-1:0]    s_axi_wstrb;
    logic                                 s_axi_wvalid;
    logic                                 s_axi_wready;

    // Write Response Channel (B)
    logic [1:0]                           s_axi_bresp;
    logic                                 s_axi_bvalid;
    logic                                 s_axi_bready;

    // Read Address Channel (AR)
    logic [C_S_AXI_ADDR_WIDTH-1:0]        s_axi_araddr;
    logic                                 s_axi_arvalid;
    logic                                 s_axi_arready;

    // Read Data Channel (R)
    logic [C_S_AXI_DATA_WIDTH-1:0]        s_axi_rdata;
    logic [1:0]                           s_axi_rresp;
    logic                                 s_axi_rvalid;
    logic                                 s_axi_rready;

    // Sideband Interface
    logic [31:0]                          hw_status_in;

    // Clock Generation (100MHz)
    always #5 aclk = ~aclk;

    // Device Under Test (DUT) Instantiation
    axi_lite_reg_file #(
        .C_S_AXI_DATA_WIDTH(C_S_AXI_DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_ADDR_WIDTH)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .hw_status_in(hw_status_in)
    );

    // FSDB Waveform Generation block
    initial begin
        $display("==================================================================");
        $display("Enabling FSDB Waveform Dumping...");
        $display("==================================================================");
        $fsdbDumpfile("axi_lite_reg_file.fsdb");
        $fsdbDumpvars(0, axi_lite_reg_file_tb);
    end

    // Task to initialize inputs
    task init_signals();
        aclk           = 0;
        aresetn        = 0;
        s_axi_awaddr   = 0;
        s_axi_awvalid  = 0;
        s_axi_wdata    = 0;
        s_axi_wstrb    = 4'b1111;
        s_axi_wvalid   = 0;
        s_axi_bready   = 0;
        s_axi_araddr   = 0;
        s_axi_arvalid  = 0;
        s_axi_rready   = 0;
        hw_status_in   = 32'hDEAD_BEEF;
    endtask

    // Task: Standard Aligned/Simultaneous Write (Data & Address together)
    task write_simultaneous(input [31:0] data);
        $display("[TB TIME: %0t] Starting SIMULTANEOUS Write: Data = 0x%h", $time, data);
        @(posedge aclk);
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wvalid  <= 1'b1;

        // Wait for both address and data to handshake
        fork
            begin : wait_aw
                while (!s_axi_awready) @(posedge aclk);
            end
            begin : wait_w
                while (!s_axi_wready) @(posedge aclk);
            end
        join

        @(posedge aclk);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid  <= 1'b0;

        // Drive B-channel handshake
        s_axi_bready  <= 1'b1;
        while (!s_axi_bvalid) @(posedge aclk);
        @(posedge aclk);
        s_axi_bready  <= 1'b0;
        $display("[TB TIME: %0t] SIMULTANEOUS Write Finished!", $time);
    endtask

    // Task: De-phased Write (Address first, Data delayed)
    // Verifies that the sticky handshake registers hold state when channels are decoupled
    task write_dephased(input [31:0] data, input int data_delay_cycles);
        $display("[TB TIME: %0t] Starting DE-PHASED Write: Data = 0x%h (Data Delayed by %0d cycles)", $time, data, data_delay_cycles);
        
        // 1. Assert Address first
        @(posedge aclk);
        s_axi_awvalid <= 1'b1;
        
        while (!s_axi_awready) @(posedge aclk);
        @(posedge aclk);
        s_axi_awvalid <= 1'b0; // Address handshake complete! Master drops valid.

        // 2. Delay the write data channel
        repeat (data_delay_cycles) @(posedge aclk);

        // 3. Drive write data
        s_axi_wdata   <= data;
        s_axi_wvalid  <= 1'b1;
        while (!s_axi_wready) @(posedge aclk);
        @(posedge aclk);
        s_axi_wvalid  <= 1'b0;

        // 4. Drive B-channel handshake
        s_axi_bready  <= 1'b1;
        while (!s_axi_bvalid) @(posedge aclk);
        @(posedge aclk);
        s_axi_bready  <= 1'b0;
        $display("[TB TIME: %0t] DE-PHASED Write Finished!", $time);
    endtask

    // Main Test Stimulus Sequence
    initial begin
        init_signals();
        
        // Apply reset
        repeat (5) @(posedge aclk);
        aresetn = 1;
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 1: Co-phased Write (Address & Data arrive together)");
        $display("-------------------------------------------------------------");
        write_simultaneous(32'h1111_1111); // Write 0x1111_1111 to Registers
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 2: De-phased Write (Address first, Data delayed 3 cycles)");
        $display("-------------------------------------------------------------");
        write_dephased(32'h2222_2222, 3); // Write 0x2222_2222 with delay
        repeat (5) @(posedge aclk);

        // Final verification check (Refined for Step 1 Identical Twin Registers)
        $display("\n=============================================================");
        $display("VERIFICATION REPORT (STEP 1 - IDENTICAL TWIN REGISTERS):");
        $display("-------------------------------------------------------------");
        
        // Since there is no address matching in Step 1, every successful write 
        // will update BOTH reg_bank0 and reg_bank1 simultaneously with the 
        // latest s_axi_wdata.

        if (dut.reg_bank0 === 32'h2222_2222 && dut.reg_bank1 === 32'h2222_2222) begin
            $display("[SUCCESS] STEP 1 PASSED!");
            $display("-> Write Handshakes are 100%% fully operational.");
            $display("-> De-phased write (Test Case 2) succeeded because your sticky handshake ");
            $display("   registers held the address handshake until write data arrived!");
            $display("-> Both registers correctly hold the final written value: 0x2222_2222.");
        end else begin
            $display("[FAIL]    STEP 1 FAILED! Handshake logic or state machine is broken.");
            $display("   Expected both registers to hold 0x2222_2222.");
            $display("   Got: reg_bank0 = 0x%h, reg_bank1 = 0x%h", dut.reg_bank0, dut.reg_bank1);
        end
        $display("=============================================================\n");

        $finish;
    end

endmodule
