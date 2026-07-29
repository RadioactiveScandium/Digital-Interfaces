`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name : axi_lite_reg_file_tb
//
// Description : 
//
// This is a comprehensive, self-checking SystemVerilog testbench for verifying the Step 4 implementation
// (Fault Protection & DECERR responses) of the AXI4-Lite Register File Slave. It generates a 100MHz clock and 
// synchronous resets, and executes several robust fault-injection tests alongside standard sanity checks:
//
// 1. TEST CASE 1: Co-phased Write to REG0 (0x000) - Aligned, Legal
//    - Expected: Write succeeds, bresp returns 2'b00 (OKAY).
//
// 2. TEST CASE 2: Unaligned Write Address (0x001) - Illegal
//    - Expected: Write is blocked, bresp returns 2'b11 (DECERR).
//
// 3. TEST CASE 3: Out-of-Range Write Address (0x100) - Illegal
//    - Expected: Write is blocked, bresp returns 2'b11 (DECERR).
//
// 4. TEST CASE 4: Co-phased Read from REG0 (0x000) - Aligned, Legal
//    - Expected: Read returns 0x1111_1111, rresp returns 2'b00 (OKAY).
//
// 5. TEST CASE 5: Unaligned Read Address (0x002) - Illegal
//    - Expected: Read returns 0x0000_0000, rresp returns 2'b11 (DECERR).
//
// 6. TEST CASE 6: Out-of-Range Read Address (0x200) - Illegal
//    - Expected: Read returns 0x0000_0000, rresp returns 2'b11 (DECERR).
//
// Waveform Output:
// - Generates a high-performance 'axi_lite_reg_file.fsdb' waveform file for Verdi analysis.
//
// Author : Gemini CLI (Architect-in-Residence) & Saransh Choudhary (Lead Designer)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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

    // Task: Standard Aligned/Simultaneous Write
    task write_simultaneous(input [11:0] addr, input [31:0] data, input [3:0] wstrb, output [1:0] bresp);
        @(posedge aclk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= wstrb;
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

        // Drive B-channel handshake and capture response
        s_axi_bready  <= 1'b1;
        while (!s_axi_bvalid) @(posedge aclk);
        bresp = s_axi_bresp;
        @(posedge aclk);
        s_axi_bready  <= 1'b0;
    endtask

    // Task: Standard Read
    task read_register(input [11:0] addr, output [31:0] rd_data, output [1:0] rresp);
        @(posedge aclk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;

        while (!s_axi_arready) @(posedge aclk);
        @(posedge aclk);
        s_axi_arvalid <= 1'b0;
        s_axi_araddr  <= 12'hXXX; // Drive garbage immediately on handshake!

        s_axi_rready  <= 1'b1;
        while (!s_axi_rvalid) @(posedge aclk);
        rd_data = s_axi_rdata;
        rresp   = s_axi_rresp;
        @(posedge aclk);
        s_axi_rready  <= 1'b0;
    endtask

    // Main Test Stimulus Sequence
    initial begin
        logic [1:0]  wr_resp1, wr_resp2, wr_resp3;
        logic [1:0]  rd_resp4, rd_resp5, rd_resp6;
        logic [31:0] rd_data4, rd_data5, rd_data6;

        init_signals();
        
        // Apply reset
        repeat (5) @(posedge aclk);
        aresetn = 1;
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 1: Legal Co-phased Write to REG0 (0x000)");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h000, 32'h1111_1111, 4'b1111, wr_resp1); 
        $display("[TB LOG] Write finished! Response received: 2'b%b (Expected: 2'b00)", wr_resp1);
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 2: Illegal Unaligned Write to Address (0x001)");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h001, 32'h2222_2222, 4'b1111, wr_resp2); 
        $display("[TB LOG] Write finished! Response received: 2'b%b (Expected: 2'b11)", wr_resp2);
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 3: Illegal Out-of-Range Write to Address (0x100)");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h100, 32'h3333_3333, 4'b1111, wr_resp3); 
        $display("[TB LOG] Write finished! Response received: 2'b%b (Expected: 2'b11)", wr_resp3);
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 4: Legal Read back from REG0 (0x000)");
        $display("-------------------------------------------------------------");
        read_register(12'h000, rd_data4, rd_resp4);
        $display("[TB LOG] Read finished! Value: 0x%h, Response: 2'b%b (Expected: 0x1111_1111, 2'b00)", rd_data4, rd_resp4);
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 5: Illegal Unaligned Read from Address (0x002)");
        $display("-------------------------------------------------------------");
        read_register(12'h002, rd_data5, rd_resp5);
        $display("[TB LOG] Read finished! Value: 0x%h, Response: 2'b%b (Expected: 0x0000_0000, 2'b11)", rd_data5, rd_resp5);
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 6: Illegal Out-of-Range Read from Address (0x200)");
        $display("-------------------------------------------------------------");
        read_register(12'h200, rd_data6, rd_resp6);
        $display("[TB LOG] Read finished! Value: 0x%h, Response: 2'b%b (Expected: 0x0000_0000, 2'b11)", rd_data6, rd_resp6);
        repeat (5) @(posedge aclk);

        // Final verification check (Refined for Step 4 Fault-Protection Audit)
        $display("\n=============================================================");
        $display("VERIFICATION REPORT (STEP 4 - FAULT INJECTION & DECERR AUDIT):");
        $display("-------------------------------------------------------------");

        // 1. Legal Write (REG0) Check
        if (dut.reg_bank0 === 32'h1111_1111 && wr_resp1 === 2'b00) begin
            $display("[SUCCESS] TC1: Legal write to REG0 succeeded with OKAY (2'b00)!");
        end else begin
            $display("[FAIL]    TC1: Legal write failed! Expected reg_bank0 = 0x1111_1111, bresp = 2'b00. Got: reg = 0x%h, bresp = 2'b%b", dut.reg_bank0, wr_resp1);
        end

        // 2. Unaligned Write Check
        if (dut.reg_bank0 === 32'h1111_1111 && wr_resp2 === 2'b11) begin
            $display("[SUCCESS] TC2: Unaligned write to 0x001 blocked and correctly returned DECERR (2'b11)!");
        end else begin
            $display("[FAIL]    TC2: Unaligned write failed! Expected write blocked, bresp = 2'b11. Got: bresp = 2'b%b", wr_resp2);
        end

        // 3. Out-of-Range Write Check
        if (dut.reg_bank0 === 32'h1111_1111 && wr_resp3 === 2'b11) begin
            $display("[SUCCESS] TC3: Out-of-range write to 0x100 blocked and correctly returned DECERR (2'b11)!");
        end else begin
            $display("[FAIL]    TC3: Out-of-range write failed! Expected write blocked, bresp = 2'b11. Got: bresp = 2'b%b", wr_resp3);
        end

        // 4. Legal Read Check
        if (rd_data4 === 32'h1111_1111 && rd_resp4 === 2'b00) begin
            $display("[SUCCESS] TC4: Legal read from REG0 returned 0x1111_1111 with OKAY (2'b00)!");
        end else begin
            $display("[FAIL]    TC4: Legal read failed! Expected data = 0x1111_1111, rresp = 2'b00. Got: data = 0x%h, rresp = 2'b%b", rd_data4, rd_resp4);
        end

        // 5. Unaligned Read Check
        if (rd_data5 === 32'h0000_0000 && rd_resp5 === 2'b11) begin
            $display("[SUCCESS] TC5: Unaligned read from 0x002 blocked and correctly returned DECERR (2'b11)!");
        end else begin
            $display("[FAIL]    TC5: Unaligned read failed! Expected data = 0x0000_0000, rresp = 2'b11. Got: data = 0x%h, rresp = 2'b%b", rd_data5, rd_resp5);
        end

        // 6. Out-of-Range Read Check
        if (rd_data6 === 32'h0000_0000 && rd_resp6 === 2'b11) begin
            $display("[SUCCESS] TC6: Out-of-range read from 0x200 blocked and correctly returned DECERR (2'b11)!");
        end else begin
            $display("[FAIL]    TC6: Out-of-range read failed! Expected data = 0x0000_0000, rresp = 2'b11. Got: data = 0x%h, rresp = 2'b%b", rd_data6, rd_resp6);
        end

        $display("=============================================================\n");

        $finish;
    end

endmodule
