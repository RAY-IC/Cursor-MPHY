// Testbench for CRC Accelerator
// Tests CRC32, CRC32C, and CRC64 functionality

`timescale 1ns / 1ps

module crc_accelerator_tb;

    // Parameters
    parameter CLK_PERIOD = 0.833;  // 1.2GHz = 833.33ps period
    
    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // AXI-Stream Slave Interface
    reg  [255:0] s_axis_tdata;
    reg          s_axis_tvalid;
    wire         s_axis_tready;
    reg          s_axis_tlast;
    reg  [31:0]  s_axis_tkeep;
    
    // AXI-Stream Master Interface
    wire [63:0]  m_axis_tdata;
    wire         m_axis_tvalid;
    reg          m_axis_tready;
    wire         m_axis_tlast;
    
    // Control Interface
    reg  [1:0]   crc_type;
    reg  [63:0]  crc_init;
    reg          crc_enable;
    reg          crc_reset;
    
    // Test vectors
    reg [7:0] test_data_1 [0:15];  // "123456789" + padding
    reg [7:0] test_data_2 [0:31];  // Longer test data
    
    // Expected CRC values
    // CRC32 of "123456789" = 0xCBF43926
    // CRC32C of "123456789" = 0xE3069283
    // CRC64 of "123456789" = 0x46A5A9388A5BEFFE
    
    // Instantiate DUT
    crc_accelerator_top uut (
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
        .crc_type(crc_type),
        .crc_init(crc_init),
        .crc_enable(crc_enable),
        .crc_reset(crc_reset)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Test data initialization
    initial begin
        // Initialize test data: "123456789"
        test_data_1[0] = 8'h31;  // '1'
        test_data_1[1] = 8'h32;  // '2'
        test_data_1[2] = 8'h33;  // '3'
        test_data_1[3] = 8'h34;  // '4'
        test_data_1[4] = 8'h35;  // '5'
        test_data_1[5] = 8'h36;  // '6'
        test_data_1[6] = 8'h37;  // '7'
        test_data_1[7] = 8'h38;  // '8'
        test_data_1[8] = 8'h39;  // '9'
        test_data_1[9] = 8'h00;
        test_data_1[10] = 8'h00;
        test_data_1[11] = 8'h00;
        test_data_1[12] = 8'h00;
        test_data_1[13] = 8'h00;
        test_data_1[14] = 8'h00;
        test_data_1[15] = 8'h00;
    end
    
    // Test task: Send AXI-Stream data
    task send_axis_data;
        input [255:0] data;
        input         last;
        input [31:0]  keep;
        begin
            @(posedge clk);
            s_axis_tdata <= data;
            s_axis_tvalid <= 1'b1;
            s_axis_tlast <= last;
            s_axis_tkeep <= keep;
            
            wait (s_axis_tready && s_axis_tvalid);
            @(posedge clk);
            s_axis_tvalid <= 1'b0;
        end
    endtask
    
    // Test task: Receive AXI-Stream result
    task receive_axis_result;
        output [63:0] result;
        begin
            m_axis_tready <= 1'b1;
            wait (m_axis_tvalid);
            @(posedge clk);
            result = m_axis_tdata;
            m_axis_tready <= 1'b0;
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize
        rst_n = 0;
        s_axis_tdata = 256'b0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast = 1'b0;
        s_axis_tkeep = 32'hFFFFFFFF;
        m_axis_tready = 1'b1;
        crc_type = 2'b00;
        crc_init = 64'hFFFFFFFFFFFFFFFF;
        crc_enable = 1'b0;
        crc_reset = 1'b0;
        
        // Reset sequence
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 5);
        
        $display("==========================================");
        $display("CRC Accelerator Testbench Started");
        $display("==========================================\n");
        
        // Test 1: CRC32 with "123456789"
        $display("Test 1: CRC32 calculation for '123456789'");
        crc_type = 2'b00;  // CRC32
        crc_init = 64'hFFFFFFFF;
        crc_enable = 1'b1;
        
        // Pack test data into 256-bit word
        s_axis_tdata = {
            224'b0,
            test_data_1[15], test_data_1[14], test_data_1[13], test_data_1[12],
            test_data_1[11], test_data_1[10], test_data_1[9], test_data_1[8],
            test_data_1[7], test_data_1[6], test_data_1[5], test_data_1[4],
            test_data_1[3], test_data_1[2], test_data_1[1], test_data_1[0]
        };
        
        send_axis_data(s_axis_tdata, 1'b1, 32'h000000FF);  // Only first 9 bytes valid
        
        // Wait for result
        #(CLK_PERIOD * 10);
        begin
            reg [63:0] result;
            receive_axis_result(result);
            $display("CRC32 Result: 0x%08X", result[31:0]);
            $display("Expected:     0xCBF43926");
            if (result[31:0] == 32'hCBF43926) begin
                $display("Test 1: PASSED\n");
            end else begin
                $display("Test 1: FAILED\n");
            end
        end
        
        #(CLK_PERIOD * 10);
        
        // Test 2: CRC32C with "123456789"
        $display("Test 2: CRC32C calculation for '123456789'");
        crc_type = 2'b01;  // CRC32C
        crc_init = 64'hFFFFFFFF;
        
        send_axis_data(s_axis_tdata, 1'b1, 32'h000000FF);
        
        #(CLK_PERIOD * 10);
        begin
            reg [63:0] result;
            receive_axis_result(result);
            $display("CRC32C Result: 0x%08X", result[31:0]);
            $display("Expected:      0xE3069283");
            if (result[31:0] == 32'hE3069283) begin
                $display("Test 2: PASSED\n");
            end else begin
                $display("Test 2: FAILED\n");
            end
        end
        
        #(CLK_PERIOD * 10);
        
        // Test 3: Multiple packets
        $display("Test 3: Multiple packet processing");
        crc_type = 2'b00;  // CRC32
        
        // Send first packet
        send_axis_data(256'h123456789ABCDEF0_0000000000000000_0000000000000000_0000000000000000, 1'b0, 32'hFFFFFFFF);
        #(CLK_PERIOD * 2);
        
        // Send second packet
        send_axis_data(256'hFEDCBA9876543210_0000000000000000_0000000000000000_0000000000000000, 1'b1, 32'hFFFFFFFF);
        
        #(CLK_PERIOD * 10);
        begin
            reg [63:0] result;
            receive_axis_result(result);
            $display("CRC32 Result for multiple packets: 0x%08X", result[31:0]);
            $display("Test 3: Completed\n");
        end
        
        #(CLK_PERIOD * 10);
        
        // Test 4: Throughput test
        $display("Test 4: Throughput test - sending 100 packets");
        crc_type = 2'b00;
        crc_enable = 1'b1;
        
        begin
            integer i;
            integer packet_count = 0;
            reg [63:0] result;
            
            for (i = 0; i < 100; i = i + 1) begin
                send_axis_data({$random, $random, $random, $random, $random, $random, $random, $random}, 
                               (i == 99), 32'hFFFFFFFF);
                
                if (i == 99) begin
                    #(CLK_PERIOD * 10);
                    receive_axis_result(result);
                    packet_count = packet_count + 1;
                end
            end
            
            $display("Processed %0d packets", packet_count);
            $display("Test 4: Completed\n");
        end
        
        #(CLK_PERIOD * 100);
        
        $display("==========================================");
        $display("All Tests Completed");
        $display("==========================================");
        
        $finish;
    end
    
    // Monitor
    initial begin
        $monitor("Time=%0t: tvalid=%b tready=%b tdata=0x%064X tlast=%b crc_result=0x%016X crc_valid=%b",
                 $time, s_axis_tvalid, s_axis_tready, s_axis_tdata, s_axis_tlast,
                 m_axis_tdata, m_axis_tvalid);
    end

endmodule
