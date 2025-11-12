// CRC32C Parallel Calculation Module for 256-bit data
// Polynomial: 0x1EDC6F41 (Castagnoli)
// Uses parallel matrix multiplication for high-speed computation

module crc32c_parallel_256 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [255:0] data_in,
    input  wire [31:0] crc_init,
    output reg  [31:0] crc_out,
    output reg         crc_valid
);

    // CRC32C polynomial: 0x1EDC6F41
    // Reversed polynomial for hardware: 0x82F63B78
    localparam [31:0] POLY = 32'h82F63B78;
    
    reg [31:0] crc_reg;
    reg [255:0] data_reg;
    reg [31:0] crc_init_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            crc_reg <= crc_init;
            crc_init_reg <= crc_init;
            crc_valid <= 1'b0;
        end else if (enable) begin
            data_reg <= data_in;
            crc_init_reg <= crc_init;
            // Use external crc_init (which is the accumulated value from engine) for calculation
            crc_reg <= compute_crc32c_256(crc_init, data_in);
            crc_valid <= 1'b1;
        end else begin
            crc_valid <= 1'b0;
        end
    end
    
    assign crc_out = crc_reg;
    
    // Compute CRC32C for 256-bit data
    function [31:0] compute_crc32c_256;
        input [31:0] crc;
        input [255:0] data;
        integer i;
        reg [31:0] temp_crc;
        begin
            temp_crc = crc;
            
            // Process 8 chunks of 32-bit data sequentially
            for (i = 0; i < 8; i = i + 1) begin
                temp_crc = compute_crc32c_32bit(temp_crc, data[(i+1)*32-1:i*32]);
            end
            
            compute_crc32c_256 = temp_crc;
        end
    endfunction
    
    // Compute CRC32C for 32-bit data chunk
    function [31:0] compute_crc32c_32bit;
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
            compute_crc32c_32bit = d;
        end
    endfunction
    
endmodule
