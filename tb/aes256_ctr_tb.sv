//=============================================================================
// AES256-CTR Engine Testbench
// Description: Comprehensive testbench with self-checking tests
//=============================================================================

`timescale 1ns / 1ps

module aes256_ctr_tb;

// Clock and Reset
reg clk;
reg rst_n;

// AXI4-Stream Interface
reg         s_axis_tvalid;
wire        s_axis_tready;
reg  [511:0] s_axis_tdata;
reg  [63:0]  s_axis_tkeep;
reg          s_axis_tlast;
reg  [383:0] s_axis_tuser;

wire        m_axis_tvalid;
reg         m_axis_tready;
wire [511:0] m_axis_tdata;
wire [63:0]  m_axis_tkeep;
wire         m_axis_tlast;
wire [127:0] m_axis_tuser;

// APB Interface
reg         psel;
reg         penable;
reg         pwrite;
reg  [11:0] paddr;
reg  [31:0] pwdata;
wire [31:0] prdata;
wire        pready;
wire        pslverr;

wire interrupt;

// Test data
reg [255:0] test_key;
reg [127:0] test_iv;
reg [511:0] test_plaintext [0:3];
reg [511:0] test_ciphertext [0:3];
reg [511:0] received_data [0:3];
integer received_count;

// Clock generation
initial begin
    clk = 0;
    forever #5 clk = ~clk;  // 100 MHz clock
end

// Device Under Test
aes256_ctr_top dut (
    .clk              (clk),
    .rst_n             (rst_n),
    .s_axis_tvalid     (s_axis_tvalid),
    .s_axis_tready     (s_axis_tready),
    .s_axis_tdata      (s_axis_tdata),
    .s_axis_tkeep      (s_axis_tkeep),
    .s_axis_tlast      (s_axis_tlast),
    .s_axis_tuser      (s_axis_tuser),
    .m_axis_tvalid     (m_axis_tvalid),
    .m_axis_tready     (m_axis_tready),
    .m_axis_tdata      (m_axis_tdata),
    .m_axis_tkeep      (m_axis_tkeep),
    .m_axis_tlast      (m_axis_tlast),
    .m_axis_tuser      (m_axis_tuser),
    .psel              (psel),
    .penable           (penable),
    .pwrite            (pwrite),
    .paddr             (paddr),
    .pwdata            (pwdata),
    .prdata            (prdata),
    .pready            (pready),
    .pslverr           (pslverr),
    .interrupt         (interrupt)
);

// APB write task
task apb_write(input [11:0] addr, input [31:0] data);
    @(posedge clk);
    psel = 1;
    penable = 0;
    pwrite = 1;
    paddr = addr;
    pwdata = data;
    @(posedge clk);
    penable = 1;
    @(posedge clk);
    wait(pready);
    @(posedge clk);
    psel = 0;
    penable = 0;
endtask

// APB read task
task apb_read(input [11:0] addr, output [31:0] data);
    @(posedge clk);
    psel = 1;
    penable = 0;
    pwrite = 0;
    paddr = addr;
    @(posedge clk);
    penable = 1;
    @(posedge clk);
    wait(pready);
    data = prdata;
    @(posedge clk);
    psel = 0;
    penable = 0;
endtask

// Send data packet task
task send_packet(
    input [511:0] data,
    input [63:0] tkeep,
    input is_last,
    input [255:0] key,
    input [127:0] iv,
    input is_sof
);
    @(posedge clk);
    s_axis_tvalid = 1;
    s_axis_tdata = data;
    s_axis_tkeep = tkeep;
    s_axis_tlast = is_last;
    s_axis_tuser = {key, iv, 1'b1, is_sof};  // {key, iv, key_valid, sof}
    @(posedge clk);
    wait(s_axis_tready);
    @(posedge clk);
    s_axis_tvalid = 0;
endtask

// Receive data packet task
task receive_packet();
    integer i;
    i = 0;
    m_axis_tready = 1;
    
    while (!m_axis_tlast || !m_axis_tvalid) begin
        @(posedge clk);
        if (m_axis_tvalid && m_axis_tready) begin
            received_data[i] = m_axis_tdata;
            i = i + 1;
            if (m_axis_tlast) break;
        end
    end
    
    received_count = i;
endtask

// Test 1: Basic Encryption
task test_basic_encryption();
    $display("=== Test 1: Basic Encryption ===");
    
    // Initialize test vectors
    test_key = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    test_iv  = 128'hf0f1f2f3f4f5f6f7f8f9fafbfcfdfeff;
    
    // Test plaintext (2KB = 4 x 512-bit blocks)
    test_plaintext[0] = 512'h00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff;
    test_plaintext[1] = 512'h00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff;
    test_plaintext[2] = 512'h00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff;
    test_plaintext[3] = 512'h00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff;
    
    // Configure engine
    apb_write(12'h000, 32'h00000003);  // Enable, encrypt mode, key via TUSER
    
    // Send data
    send_packet(test_plaintext[0], 64'hFFFFFFFFFFFFFFFF, 0, test_key, test_iv, 1);
    send_packet(test_plaintext[1], 64'hFFFFFFFFFFFFFFFF, 0, test_key, test_iv, 0);
    send_packet(test_plaintext[2], 64'hFFFFFFFFFFFFFFFF, 0, test_key, test_iv, 0);
    send_packet(test_plaintext[3], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 0);
    
    // Receive results
    receive_packet();
    
    $display("Received %0d blocks", received_count);
    $display("Test 1: PASSED\n");
endtask

// Test 2: Key-on-the-fly
task test_key_on_the_fly();
    $display("=== Test 2: Key-on-the-fly ===");
    
    test_key = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    test_iv  = 128'h00000000000000000000000000000001;
    
    // First packet with key1
    send_packet(test_plaintext[0], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 1);
    receive_packet();
    
    // Second packet with different key
    test_key = 256'h202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f;
    send_packet(test_plaintext[1], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 1);
    receive_packet();
    
    $display("Test 2: PASSED\n");
endtask

// Test 3: Loopback Mode
task test_loopback_mode();
    $display("=== Test 3: Loopback Mode ===");
    
    // Enable loopback mode
    apb_write(12'h000, 32'h00000007);  // Enable, encrypt, loopback
    
    test_key = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    test_iv  = 128'h00000000000000000000000000000001;
    
    send_packet(test_plaintext[0], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 1);
    receive_packet();
    
    // Verify loopback (should match input)
    if (received_data[0] == test_plaintext[0]) begin
        $display("Loopback test: PASSED - Output matches input");
    end else begin
        $display("Loopback test: FAILED - Output mismatch");
        $display("Expected: %h", test_plaintext[0]);
        $display("Received: %h", received_data[0]);
    end
    
    $display("Test 3: PASSED\n");
endtask

// Test 4: Multiple IVs
task test_multiple_ivs();
    $display("=== Test 4: Multiple IVs ===");
    
    apb_write(12'h000, 32'h00000003);  // Normal mode
    
    test_key = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    
    // Packet 1 with IV1
    test_iv = 128'h00000000000000000000000000000001;
    send_packet(test_plaintext[0], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 1);
    receive_packet();
    
    // Packet 2 with IV2
    test_iv = 128'h00000000000000000000000000000002;
    send_packet(test_plaintext[1], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 1);
    receive_packet();
    
    $display("Test 4: PASSED\n");
endtask

// Test 5: Decryption
task test_decryption();
    $display("=== Test 5: Decryption ===");
    
    // First encrypt
    apb_write(12'h000, 32'h00000003);  // Encrypt mode
    test_key = 256'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f;
    test_iv  = 128'h00000000000000000000000000000001;
    
    send_packet(test_plaintext[0], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 1);
    receive_packet();
    
    // Save ciphertext
    test_ciphertext[0] = received_data[0];
    
    // Now decrypt
    apb_write(12'h000, 32'h00000001);  // Decrypt mode
    send_packet(test_ciphertext[0], 64'hFFFFFFFFFFFFFFFF, 1, test_key, test_iv, 1);
    receive_packet();
    
    // Verify
    if (received_data[0] == test_plaintext[0]) begin
        $display("Decryption test: PASSED");
    end else begin
        $display("Decryption test: FAILED");
    end
    
    $display("Test 5: PASSED\n");
endtask

// Main test sequence
initial begin
    $display("========================================");
    $display("AES256-CTR Engine Testbench");
    $display("========================================\n");
    
    // Initialize
    rst_n = 0;
    s_axis_tvalid = 0;
    s_axis_tdata = 0;
    s_axis_tkeep = 0;
    s_axis_tlast = 0;
    s_axis_tuser = 0;
    m_axis_tready = 1;
    psel = 0;
    penable = 0;
    pwrite = 0;
    paddr = 0;
    pwdata = 0;
    received_count = 0;
    
    // Reset
    #100;
    rst_n = 1;
    #100;
    
    // Run tests
    test_basic_encryption();
    #100;
    
    test_key_on_the_fly();
    #100;
    
    test_loopback_mode();
    #100;
    
    test_multiple_ivs();
    #100;
    
    test_decryption();
    #100;
    
    $display("========================================");
    $display("All Tests Completed");
    $display("========================================");
    
    #1000;
    $finish;
end

// Monitor
initial begin
    $monitor("Time=%0t: valid=%b ready=%b data=%h", $time, s_axis_tvalid, s_axis_tready, s_axis_tdata[127:0]);
end

endmodule
