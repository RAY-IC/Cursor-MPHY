// Performance Testbench for Multi-Pipeline Hash Module
// Tests throughput and verifies 15GB/s target

`timescale 1ns / 1ps

module tb_hash_top_multi;

    // Parameters
    parameter CLK_PERIOD = 1.0;  // 1ns period = 1GHz
    parameter NUM_PIPELINES = 16;
    parameter TEST_DATA_SIZE = 1024 * 1024;  // 1MB test data
    
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
    
    // Performance counters
    integer input_byte_count;
    integer output_byte_count;
    integer input_cycle_count;
    integer output_cycle_count;
    integer start_time;
    integer end_time;
    real throughput_gbps;
    
    // Test data generation
    reg [7:0] test_data [0:TEST_DATA_SIZE-1];
    integer data_ptr;
    
    // Instantiate DUT
    hash_top_multi #(
        .NUM_PIPELINES(NUM_PIPELINES)
    ) uut (
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
    
    // Generate test data
    initial begin
        integer i;
        for (i = 0; i < TEST_DATA_SIZE; i = i + 1) begin
            test_data[i] = i[7:0];  // Simple pattern
        end
    end
    
    // Task: Send large data stream
    task send_large_data;
        input integer data_size;
        integer i, j;
        reg [255:0] temp_data;
        begin
            s_axis_tvalid = 1'b0;
            s_axis_tlast = 1'b0;
            s_axis_tkeep = 32'hFFFFFFFF;
            data_ptr = 0;
            input_byte_count = 0;
            input_cycle_count = 0;
            
            // Wait for ready
            wait(ready);
            #(CLK_PERIOD);
            
            start_time = $time;
            
            // Send data in 256-bit chunks
            while (data_ptr < data_size) begin
                temp_data = 256'b0;
                for (j = 0; j < 32 && (data_ptr + j) < data_size; j = j + 1) begin
                    temp_data[j*8 +: 8] = test_data[data_ptr + j];
                end
                
                s_axis_tdata = temp_data;
                s_axis_tvalid = 1'b1;
                
                if (data_ptr + 32 >= data_size) begin
                    s_axis_tlast = 1'b1;
                    s_axis_tkeep = 32'hFFFFFFFF >> (32 - (data_size - data_ptr));
                end
                
                @(posedge clk);
                input_cycle_count = input_cycle_count + 1;
                
                if (s_axis_tready && s_axis_tvalid) begin
                    input_byte_count = input_byte_count + 32;
                    data_ptr = data_ptr + 32;
                end
            end
            
            s_axis_tvalid = 1'b0;
            s_axis_tlast = 1'b0;
            #(CLK_PERIOD);
        end
    endtask
    
    // Task: Receive hash results
    task receive_results;
        integer result_count;
        begin
            m_axis_tready = 1'b1;
            output_byte_count = 0;
            output_cycle_count = 0;
            result_count = 0;
            
            while (!done || m_axis_tvalid) begin
                @(posedge clk);
                output_cycle_count = output_cycle_count + 1;
                
                if (m_axis_tvalid && m_axis_tready) begin
                    result_count = result_count + 1;
                    // Hash output is fixed size: MD5=16 bytes, SHA256=32 bytes, SHA1=20 bytes
                    case (algorithm_sel)
                        2'b00: output_byte_count = output_byte_count + 16;  // MD5
                        2'b01: output_byte_count = output_byte_count + 32;  // SHA256
                        2'b10: output_byte_count = output_byte_count + 20;  // SHA1
                    endcase
                end
            end
            
            end_time = $time;
            m_axis_tready = 1'b0;
        end
    endtask
    
    // Performance test task
    task performance_test;
        input [1:0] alg;
        input integer data_size;
        input [255:0] expected_hash;  // For verification
        begin
            $display("========================================");
            case (alg)
                2'b00: $display("Performance Test: MD5");
                2'b01: $display("Performance Test: SHA256");
                2'b10: $display("Performance Test: SHA1");
            endcase
            $display("Data Size: %0d bytes", data_size);
            $display("========================================");
            
            algorithm_sel = alg;
            start = 1'b1;
            #(CLK_PERIOD);
            start = 1'b0;
            
            // Send data
            fork
                send_large_data(data_size);
            join_none
            
            // Receive results
            fork
                receive_results();
            join_none
            
            // Wait for completion
            wait(done);
            #(100*CLK_PERIOD);
            
            // Calculate throughput
            throughput_gbps = (input_byte_count * 8.0) / (end_time - start_time);
            
            $display("Input Statistics:");
            $display("  Bytes sent: %0d", input_byte_count);
            $display("  Cycles: %0d", input_cycle_count);
            $display("Output Statistics:");
            $display("  Bytes received: %0d", output_byte_count);
            $display("  Cycles: %0d", output_cycle_count);
            $display("Performance:");
            $display("  Time: %0d ns", end_time - start_time);
            $display("  Throughput: %0.2f Gbps", throughput_gbps);
            $display("  Throughput: %0.2f GB/s", throughput_gbps / 8.0);
            
            if (throughput_gbps / 8.0 >= 15.0) begin
                $display("*** PASS: Throughput >= 15 GB/s ***");
            end else begin
                $display("*** WARNING: Throughput < 15 GB/s ***");
            end
            
            $display("========================================\n");
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
        $display("Multi-Pipeline Hash Module Performance Test");
        $display("Number of Pipelines: %0d", NUM_PIPELINES);
        $display("Target Throughput: 15 GB/s");
        $display("========================================");
        
        // Wait for ready
        wait(ready);
        #(10*CLK_PERIOD);
        
        // Performance tests with different data sizes
        // Test 1: 64KB data
        performance_test(2'b01, 64*1024, 256'b0);  // SHA256
        
        // Test 2: 256KB data
        performance_test(2'b01, 256*1024, 256'b0);  // SHA256
        
        // Test 3: 1MB data
        performance_test(2'b01, 1024*1024, 256'b0);  // SHA256
        
        // Test 4: MD5 with 1MB data
        performance_test(2'b00, 1024*1024, 256'b0);  // MD5
        
        // Test 5: SHA1 with 1MB data
        performance_test(2'b10, 1024*1024, 256'b0);  // SHA1
        
        $display("========================================");
        $display("All Performance Tests Completed");
        $display("========================================");
        
        #(100*CLK_PERIOD);
        $finish;
    end
    
    // Monitor for debugging
    initial begin
        // Uncomment for detailed monitoring
        // $monitor("Time=%0t: alg=%b, input_valid=%b, input_ready=%b, output_valid=%b, output_ready=%b, done=%b",
        //          $time, algorithm_sel, s_axis_tvalid, s_axis_tready, m_axis_tvalid, m_axis_tready, done);
    end

endmodule
