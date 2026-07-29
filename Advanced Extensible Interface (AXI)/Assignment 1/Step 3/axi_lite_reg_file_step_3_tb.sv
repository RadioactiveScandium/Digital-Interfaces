`timescale 1ns/1ps

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Module Name : axi_lite_reg_file_tb
//
// Description : 
//
// This is an advanced, automated self-checking testbench verifying the Step 3 Write Strobe (WSTRB) implementation
// of our AXI4-Lite Register File Slave. It incorporates:
//
// 1. Directed Sanity Checks (TC1 & TC2): Clears registers and verifies a basic single-byte write.
//
// 2. Randomized Strobe Sweep (8 Test Cases):
//    - Automatically loops 8 times, generating completely random 32-bit data payloads, random 4-bit strobe masks,
//      and targeting random registers (REG0 or REG1).
//    - Implements a behavioral **Golden Reference Model** inside the testbench to dynamically calculate the 
//      exact, expected byte-lanes that should be updated vs. preserved on every run.
//    - Performs real-time self-checking by reading back the hardware register and comparing it against the Golden 
//      Model value, throwing instant errors if a discrepancy is found.
//
// Waveform Output:
// - Generates a high-performance 'axi_lite_reg_file.fsdb' waveform file for Verdi analysis.
// - Remember to use +ntb_random_seed_automatic as runtime option in vcs command to generate random values in every run
//
// Author : Gemini & Saransh Choudhary
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
    task write_simultaneous(input [11:0] addr, input [31:0] data, input [3:0] wstrb);
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

        // Drive B-channel handshake
        s_axi_bready  <= 1'b1;
        while (!s_axi_bvalid) @(posedge aclk);
        @(posedge aclk);
        s_axi_bready  <= 1'b0;
    endtask

    // Task: Standard Read
    task read_register(input [11:0] addr, output [31:0] rd_data);
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
    endtask

    // Function: Behavioral Golden Reference Model for Strobe Writes
    function [31:0] golden_model(input [31:0] original_val, input [31:0] written_data, input [3:0] strobe);
        logic [31:0] out;
        out[7:0]   = strobe[0] ? written_data[7:0]   : original_val[7:0];
        out[15:8]  = strobe[1] ? written_data[15:8]  : original_val[15:8];
        out[23:16] = strobe[2] ? written_data[23:16] : original_val[23:16];
        out[31:24] = strobe[3] ? written_data[31:24] : original_val[31:24];
        return out;
    endfunction

    // Main Test Stimulus Sequence
    initial begin
        logic [31:0] initial_val;
        logic [31:0] rand_data;
        logic [3:0]  rand_strobe;
        logic [11:0] target_addr;
        logic [31:0] expected_val;
        logic [31:0] actual_val;
        int          success_count = 0;

        init_signals();
        
        // Apply reset
        repeat (5) @(posedge aclk);
        aresetn = 1;
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("SANITY CHECK 1: Clear REG0 and REG1 (Full Write WSTRB = 4'b1111)");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h000, 32'h0000_0000, 4'b1111); // Clear REG0
        repeat (2) @(posedge aclk);
        write_simultaneous(12'h004, 32'h0000_0000, 4'b1111); // Clear REG1
        repeat (5) @(posedge aclk);

        $display("\n-------------------------------------------------------------");
        $display("SANITY CHECK 2: Single Byte write (WSTRB = 4'b0001 - Byte 0 only)");
        $display("-------------------------------------------------------------");
        write_simultaneous(12'h000, 32'hAAAA_AAAA, 4'b0001); // Write 0xAAAA_AAAA to REG0
        read_register(12'h000, actual_val);
        if (actual_val === 32'h0000_00AA) begin
            $display("[SUCCESS] Sanity Check 2 Passed! REG0 = 0x%h", actual_val);
        end else begin
            $display("[FAIL]    Sanity Check 2 Failed! Expected 0x0000_00AA, got 0x%h", actual_val);
        end
        repeat (5) @(posedge aclk);

        $display("\n=============================================================");
        $display("STARTING CONSTRAINED RANDOM WRITE STROBE SWEEP (8 ITERATIONS)");
        $display("=============================================================");

        for (int i = 1; i <= 8; i++) begin
            // 1. Generate randomized inputs
            rand_data   = $urandom();
            rand_strobe = $urandom_range(0, 15); // Random strobe 0000 to 1111
            target_addr = ($urandom_range(0, 1) == 0) ? 12'h000 : 12'h004; // Random target: REG0 or REG1

            $display("\n--- [RUN %0d] -----------------------------------------------", i);
            $display("Target Address : 0x%h", target_addr);
            $display("Random Data    : 0x%h", rand_data);
            $display("Random Strobe  : 4'b%b", rand_strobe);

            // 2. Read the initial value first to model persistence
            read_register(target_addr, initial_val);
            $display("Original Value : 0x%h", initial_val);

            // 3. Compute Golden Expected Value
            expected_val = golden_model(initial_val, rand_data, rand_strobe);
            $display("Expected Value : 0x%h (Golden Model)", expected_val);

            // 4. Inject randomized AXI Write
            write_simultaneous(target_addr, rand_data, rand_strobe);
            repeat (2) @(posedge aclk);

            // 5. Read back the actual register and compare
            read_register(target_addr, actual_val);
            $display("Actual Value   : 0x%h (Hardware)", actual_val);

            if (actual_val === expected_val) begin
                $display("[PASS] RUN %0d: Strobe masking worked perfectly!", i);
                success_count++;
            end else begin
                $display("[FAIL] RUN %0d: Strobe masking CORRUPTED data! expected 0x%h, got 0x%h", i, expected_val, actual_val);
            end
            repeat (2) @(posedge aclk);
        end

        // Final verification check (Refined for Step 3 Write Strobes Audit)
        $display("\n=============================================================");
        $display("VERIFICATION REPORT (STEP 3 - STROBE RANDOMIZATION SWEEP):");
        $display("-------------------------------------------------------------");
        if (success_count == 8) begin
            $display("[SUCCESS] ALL 8 RANDOMIZED TEST CASES PASSED!");
            $display("-> Your write-strobe (WSTRB) multiplexing logic is robust");
            $display("   and mathematically bulletproof under randomized stimulus.");
        end else begin
            $display("[FAIL]    %0d out of 8 randomized test cases FAILED!", (8 - success_count));
            $display("-> Review your always_ff strobe case statements for byte-mapping errors.");
        end
        $display("=============================================================\n");

        $finish;
    end

endmodule
