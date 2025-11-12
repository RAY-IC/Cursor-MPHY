// CRC32 Parallel Calculation Module for 256-bit data
// Polynomial: 0x04C11DB7 (IEEE 802.3)
// Uses parallel matrix multiplication for high-speed computation

module crc32_parallel_256 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [255:0] data_in,
    input  wire [31:0] crc_init,
    output reg  [31:0] crc_out,
    output reg         crc_valid
);

    // CRC32 polynomial: 0x04C11DB7
    // Reversed polynomial for hardware: 0xEDB88320
    localparam [31:0] POLY = 32'hEDB88320;
    
    reg [31:0] crc_reg;
    reg [255:0] data_reg;
    reg [31:0] crc_init_reg;
    
    // Parallel CRC32 calculation for 256-bit data
    // This uses a simplified approach: process data in 32-bit chunks
    // and combine results using CRC linearity property
    
    always @(posedge clk) begin
        if (!rst_n) begin
            crc_reg <= crc_init;
            crc_init_reg <= crc_init;
            crc_valid <= 1'b0;
        end else if (enable) begin
            data_reg <= data_in;
            crc_init_reg <= crc_init;  // Update initial value from external accumulator
            // Use external crc_init (which is the accumulated value from engine) for calculation
            crc_reg <= compute_crc32_256(crc_init, data_in);
            crc_valid <= 1'b1;
        end else begin
            crc_valid <= 1'b0;
        end
    end
    
    assign crc_out = crc_reg;
    
    // Compute CRC32 for 256-bit data
    function [31:0] compute_crc32_256;
        input [31:0] crc;
        input [255:0] data;
        integer i, j;
        reg [31:0] temp_crc;
        reg [31:0] chunk_crc [0:7];
        begin
            temp_crc = crc;
            
            // Process 8 chunks of 32-bit data
            for (i = 0; i < 8; i = i + 1) begin
                chunk_crc[i] = compute_crc32_32bit(temp_crc, data[(i+1)*32-1:i*32]);
                temp_crc = chunk_crc[i];
            end
            
            compute_crc32_256 = temp_crc;
        end
    endfunction
    
    // Compute CRC32 for 32-bit data chunk
    function [31:0] compute_crc32_32bit;
        input [31:0] crc;
        input [31:0] data;
        integer i;
        reg [31:0] d;
        begin
            d = data ^ crc;
            for (i = 0; i < 32; i = i + 1) begin
                if (d[0]) begin
                    d = (d >> 1) ^ POLY;
                end else begin
                    d = d >> 1;
                end
            end
            compute_crc32_32bit = d;
        end
    endfunction
    
endmodule
