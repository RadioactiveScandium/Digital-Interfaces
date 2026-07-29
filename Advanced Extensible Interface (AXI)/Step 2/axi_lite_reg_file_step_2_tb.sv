////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name : axi_lite_reg_file_tb
//
// Description : 
//
// This is a self-checking SystemVerilog testbench for verifying the Step 2 implementation of the AXI4-Lite
// Register File Slave. It generates a 100MHz clock and synchronous resets, and executes four distinct tests:
//
// 1. TEST CASE 1: Co-phased Write (REG0)
//    - Asserts both AW (Address) and W (Data) handshakes on the exact same clock cycle to write to REG0 (0x000).
//
// 2. TEST CASE 2: De-phased/De-coupled Write (REG1)
//    - Asserts the AW handshake first to REG1 (0x004). Once completed, the master drops AWVALID and drives garbage
//      values on the AWADDR lines. After a 3-cycle delay, it handshakes the W channel.
//    - This proves that your 's_axi_awaddr_reg' successfully locks and preserves the target address.
//
// 3. TEST CASE 3: Simultaneous Read (REG0)
//    - Issues an AR handshake to REG0 (0x000) and completes the R channel handshake to read the value back.
//
// 4. TEST CASE 4: De-phased Read (REG1)
//    - Issues an AR handshake to REG1 (0x004), drops ARVALID, drives garbage on ARADDR, delays for 3 cycles,
//      and then completes the R channel handshake to read the value back.
//
// Waveform Output:
// - Generates a high-performance 'axi_lite_reg_file.fsdb' waveform file for Verdi analysis.
//
// Author : Gemini CLI (Architect-in-Residence) & Saransh Choudhary (Lead Designer)
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
    task write_simultaneous(input [11:0] addr, input [31:0] data);
        $display("[TB TIME: %0t] Starting SIMULTANEOUS Write: Addr = 0x%h, Data = 0x%h", $time, addr, data);
        @(posedge aclk);
        s_axi_awaddr  <= addr;
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
    // Exposes the Address-Slippage bug when address matches are checked combinationally
    task write_dephased(input [11:0] addr, input [31:0] data, input int data_delay_cycles);
        $display("[TB TIME: %0t] Starting DE-PHASED Write: Addr = 0x%h, Data = 0x%h (Data Delayed by %0d cycles)", $time, addr, data, data_delay_cycles);
        
        // 1. Assert Address first
        @(posedge aclk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        
        while (!s_axi_awready) @(posedge aclk);
        @(posedge aclk);
        s_axi_awvalid <= 1'b0; // Address handshake complete! Master drops valid.
        s_axi_awaddr  <= 12'hXXX; // Master drives garbage address lines now!

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

    // Task: Standard Read (Simultaneous AR and R)
    task read_register(input [11:0] addr, output [31:0] rd_data);
        $display("[TB TIME: %0t] Starting READ: Addr = 0x%h", $time, addr);
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
        @(posedge aclk);
        s_axi_rready  <= 1'b0;
        $display("[TB TIME: %0t] READ Finished! Received Data = 0x%h", $time, rd_data);
    endtask

    // Main Test Stimulus Sequence
    initial begin
        logic [31:0] read_val0;
        logic [31:0] read_val1;
        logic [31:0] read_val2;
        logic [31:0] read_val3;

        init_signals();
        
        // Apply reset
        repeat (5) @(posedge aclk);
        aresetn = 1;
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 1: Co-phased Write to REG0 (0x000)");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h000, 32'h1111_1111); 
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 2: De-phased Write to REG1 (0x004) - Address first!");
        $display("-------------------------------------------------------------");
        write_dephased(12'h004, 32'h2222_2222, 3); 
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 3: Read back REG0 (0x000)");
        $display("-------------------------------------------------------------");
        read_register(12'h000, read_val0);
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 4: Read back REG1 (0x004)");
        $display("-------------------------------------------------------------");
        read_register(12'h004, read_val1);
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 5: Write to REG2 (0x008 - Write Only) and Read back");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h008, 32'hAAAA_AAAA); // CPU attempts write
        repeat (2) @(posedge aclk);
        read_register(12'h008, read_val2);         // CPU reads it back (should return 0!)
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("TEST CASE 6: Write to REG3 (0x00C - Read Only) and Read back");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h00C, 32'hBBBB_BBBB); // CPU attempts to overwrite
        repeat (2) @(posedge aclk);
        read_register(12'h00C, read_val3);         // CPU reads (should return live hw_status_in)
        repeat (5) @(posedge aclk);

        // Final verification check (Refined for Step 2 Address-Decoding & Access Policies)
        $display("\n=============================================================");
        $display("VERIFICATION REPORT (STEP 2 - WRITE/READ DECODING AUDIT):");
        $display("-------------------------------------------------------------");

        // 1. REG0 Check
        if (dut.reg_bank0 === 32'h1111_1111 && read_val0 === 32'h1111_1111) begin
            $display("[SUCCESS] REG0 R/W: Correctly wrote and read back 0x1111_1111");
        end else begin
            $display("[FAIL]    REG0 R/W: Expected 0x1111_1111, got write_val = 0x%h, read_val = 0x%h", dut.reg_bank0, read_val0);
        end

        // 2. REG1 Check
        if (dut.reg_bank1 === 32'h2222_2222 && read_val1 === 32'h2222_2222) begin
            $display("[SUCCESS] REG1 R/W: Correctly wrote and read back 0x2222_2222 (Slippage Resolved!)");
        end else begin
            $display("[FAIL]    REG1 R/W: Expected 0x2222_2222, got write_val = 0x%h, read_val = 0x%h", dut.reg_bank1, read_val1);
        end

        // 3. REG2 Check (Write-Only policy check)
        if (read_val2 === 32'h0000_0000) begin
            $display("[SUCCESS] REG2 WRITE-ONLY: Write-only policy verified! Reads returned 0x0000_0000.");
        end else begin
            $display("[FAIL]    REG2 WRITE-ONLY: Policy violation! Reads to write-only register returned 0x%h", read_val2);
        end

        // 4. REG3 Check (Read-Only policy check)
        if (read_val3 === 32'hDEAD_BEEF) begin
            $display("[SUCCESS] REG3 READ-ONLY: Read-only policy verified! Writes ignored, read returned hw_status_in (0xDEAD_BEEF).");
        end else begin
            $display("[FAIL]    REG3 READ-ONLY: Policy violation! Read returned 0x%h instead of 0xDEAD_BEEF.", read_val3);
        end

        $display("=============================================================\n");

        $finish;
    end

endmodule
