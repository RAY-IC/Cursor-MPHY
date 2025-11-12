// Testbench for Hash Top Module
// Tests MD5, SHA256, and SHA1 with standard test vectors

`timescale 1ns / 1ps

module tb_hash_top;

    // Parameters
    parameter CLK_PERIOD = 1.0;  // 1ns period = 1GHz
    
    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // AXI-Stream Slave Interface
    reg [255:0] s_axis_tdata;
    reg         s_axis_tvalid;
    wire        s_axis_tready;
    reg         s_axis_tlast;
    reg [31:0]  s_axis_tkeep;
    
    // AXI-Stream Master Interface
    wire [255:0] m_axis_tdata;
    wire         m_axis_tvalid;
    reg          m_axis_tready;
    wire         m_axis_tlast;
    
    // Control Interface
    reg [1:0]   algorithm_sel;
    reg         start;
    wire        ready;
    wire        done;
    
    // Test vectors
    // MD5 test vectors
    reg [7:0] md5_test1 [0:0];  // Empty string
    reg [7:0] md5_test2 [0:2];  // "abc"
    
    // SHA256 test vectors
    reg [7:0] sha256_test1 [0:0];  // Empty string
    reg [7:0] sha256_test2 [0:2];  // "abc"
    
    // SHA1 test vectors
    reg [7:0] sha1_test1 [0:0];  // Empty string
    reg [7:0] sha1_test2 [0:2];  // "abc"
    
    // Expected results
    reg [127:0] md5_expected1 = 128'hd41d8cd98f00b204e9800998ecf8427e;
    reg [127:0] md5_expected2 = 128'h900150983cd24fb0d6963f7d28e17f72;
    
    reg [255:0] sha256_expected1 = 256'he3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855;
    reg [255:0] sha256_expected2 = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;
    
    reg [159:0] sha1_expected1 = 160'hda39a3ee5e6b4b0d3255bfef95601890afd80709;
    reg [159:0] sha1_expected2 = 160'ha9993e364706816aba3e25717850c26c9cd0d89d;
    
    // Instantiate DUT
    hash_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tkeep(s_axis_tkeep),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .algorithm_sel(algorithm_sel),
        .start(start),
        .ready(ready),
        .done(done)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Initialize test vectors
    initial begin
        // MD5 test vectors
        md5_test1[0] = 8'h00;  // Empty (will be handled as empty)
        
        md5_test2[0] = 8'h61;  // 'a'
        md5_test2[1] = 8'h62;  // 'b'
        md5_test2[2] = 8'h63;  // 'c'
        
        // SHA256 test vectors (same as MD5)
        sha256_test1[0] = 8'h00;
        sha256_test2[0] = 8'h61;
        sha256_test2[1] = 8'h62;
        sha256_test2[2] = 8'h63;
        
        // SHA1 test vectors (same as MD5)
        sha1_test1[0] = 8'h00;
        sha1_test2[0] = 8'h61;
        sha1_test2[1] = 8'h62;
        sha1_test2[2] = 8'h63;
    end
    
    // Test task: Send data via AXI-Stream
    task send_axi_data;
        input [7:0] data [];
        input integer data_len;
        integer i, j;
        reg [255:0] temp_data;
        begin
            s_axis_tvalid = 1'b0;
            s_axis_tlast = 1'b0;
            s_axis_tkeep = 32'hFFFFFFFF;
            
            // Wait for ready
            wait(s_axis_tready);
            #(CLK_PERIOD);
            
            // Send data in 256-bit chunks
            for (i = 0; i < data_len; i = i + 32) begin
                temp_data = 256'b0;
                for (j = 0; j < 32 && (i+j) < data_len; j = j + 1) begin
                    temp_data[j*8 +: 8] = data[i+j];
                end
                
                s_axis_tdata = temp_data;
                s_axis_tvalid = 1'b1;
                if (i + 32 >= data_len) begin
                    s_axis_tlast = 1'b1;
                    // Adjust tkeep for partial last word
                    s_axis_tkeep = 32'hFFFFFFFF >> (32 - (data_len - i));
                end
                
                @(posedge clk);
                while (!s_axis_tready) @(posedge clk);
            end
            
            s_axis_tvalid = 1'b0;
            s_axis_tlast = 1'b0;
            #(CLK_PERIOD);
        end
    endtask
    
    // Test task: Receive hash result
    task receive_hash_result;
        output [255:0] result;
        begin
            m_axis_tready = 1'b1;
            wait(m_axis_tvalid);
            @(posedge clk);
            result = m_axis_tdata;
            m_axis_tready = 1'b0;
            #(CLK_PERIOD);
        end
    endtask
    
    // Test task: Test MD5
    task test_md5;
        input [7:0] test_data [];
        input integer data_len;
        input [127:0] expected;
        reg [255:0] result;
        begin
            $display("=== Testing MD5 ===");
            algorithm_sel = 2'b00;
            start = 1'b1;
            #(CLK_PERIOD);
            start = 1'b0;
            
            // Send test data
            send_axi_data(test_data, data_len);
            
            // Wait for done
            wait(done);
            #(10*CLK_PERIOD);
            
            // Receive result
            receive_hash_result(result);
            
            // Check result
            if (result[127:0] == expected) begin
                $display("PASS: MD5 hash matches expected value");
                $display("  Expected: %h", expected);
                $display("  Got:      %h", result[127:0]);
            end else begin
                $display("FAIL: MD5 hash mismatch");
                $display("  Expected: %h", expected);
                $display("  Got:      %h", result[127:0]);
            end
            
            #(10*CLK_PERIOD);
        end
    endtask
    
    // Test task: Test SHA256
    task test_sha256;
        input [7:0] test_data [];
        input integer data_len;
        input [255:0] expected;
        reg [255:0] result;
        begin
            $display("=== Testing SHA256 ===");
            algorithm_sel = 2'b01;
            start = 1'b1;
            #(CLK_PERIOD);
            start = 1'b0;
            
            // Send test data
            send_axi_data(test_data, data_len);
            
            // Wait for done
            wait(done);
            #(10*CLK_PERIOD);
            
            // Receive result
            receive_hash_result(result);
            
            // Check result
            if (result == expected) begin
                $display("PASS: SHA256 hash matches expected value");
                $display("  Expected: %h", expected);
                $display("  Got:      %h", result);
            end else begin
                $display("FAIL: SHA256 hash mismatch");
                $display("  Expected: %h", expected);
                $display("  Got:      %h", result);
            end
            
            #(10*CLK_PERIOD);
        end
    endtask
    
    // Test task: Test SHA1
    task test_sha1;
        input [7:0] test_data [];
        input integer data_len;
        input [159:0] expected;
        reg [255:0] result;
        begin
            $display("=== Testing SHA1 ===");
            algorithm_sel = 2'b10;
            start = 1'b1;
            #(CLK_PERIOD);
            start = 1'b0;
            
            // Send test data
            send_axi_data(test_data, data_len);
            
            // Wait for done
            wait(done);
            #(10*CLK_PERIOD);
            
            // Receive result
            receive_hash_result(result);
            
            // Check result
            if (result[159:0] == expected) begin
                $display("PASS: SHA1 hash matches expected value");
                $display("  Expected: %h", expected);
                $display("  Got:      %h", result[159:0]);
            end else begin
                $display("FAIL: SHA1 hash mismatch");
                $display("  Expected: %h", expected);
                $display("  Got:      %h", result[159:0]);
            end
            
            #(10*CLK_PERIOD);
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize
        rst_n = 1'b0;
        s_axis_tdata = 256'b0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast = 1'b0;
        s_axis_tkeep = 32'hFFFFFFFF;
        m_axis_tready = 1'b0;
        algorithm_sel = 2'b00;
        start = 1'b0;
        
        // Reset
        #(10*CLK_PERIOD);
        rst_n = 1'b1;
        #(10*CLK_PERIOD);
        
        $display("========================================");
        $display("Hash Module Testbench Started");
        $display("========================================");
        
        // Wait for ready
        wait(ready);
        #(10*CLK_PERIOD);
        
        // Test MD5 with empty string
        test_md5(md5_test1, 0, md5_expected1);
        
        // Test MD5 with "abc"
        test_md5(md5_test2, 3, md5_expected2);
        
        // Test SHA256 with empty string
        test_sha256(sha256_test1, 0, sha256_expected1);
        
        // Test SHA256 with "abc"
        test_sha256(sha256_test2, 3, sha256_expected2);
        
        // Test SHA1 with empty string
        test_sha1(sha1_test1, 0, sha1_expected1);
        
        // Test SHA1 with "abc"
        test_sha1(sha1_test2, 3, sha1_expected2);
        
        $display("========================================");
        $display("All Tests Completed");
        $display("========================================");
        
        #(100*CLK_PERIOD);
        $finish;
    end
    
    // Monitor for debugging
    initial begin
        $monitor("Time=%0t: algorithm_sel=%b, start=%b, done=%b, s_axis_tvalid=%b, s_axis_tready=%b, m_axis_tvalid=%b, m_axis_tready=%b",
                 $time, algorithm_sel, start, done, s_axis_tvalid, s_axis_tready, m_axis_tvalid, m_axis_tready);
    end

endmodule
