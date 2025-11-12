// CRC64 Parallel Calculation Module for 256-bit data
// Polynomial: 0x42F0E1EBA9EA3693 (ECMA-182)
// Uses parallel matrix multiplication for high-speed computation

module crc64_parallel_256 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [255:0] data_in,
    input  wire [63:0] crc_init,
    output reg  [63:0] crc_out,
    output reg         crc_valid
);

    // CRC64 polynomial: 0x42F0E1EBA9EA3693
    // Reversed polynomial for hardware: 0xC96C5795D7870F42
    localparam [63:0] POLY = 64'hC96C5795D7870F42;
    
    reg [63:0] crc_reg;
    reg [255:0] data_reg;
    reg [63:0] crc_init_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            crc_reg <= crc_init;
            crc_init_reg <= crc_init;
            crc_valid <= 1'b0;
        end else if (enable) begin
            data_reg <= data_in;
            crc_init_reg <= crc_init;
            // Use external crc_init (which is the accumulated value from engine) for calculation
            crc_reg <= compute_crc64_256(crc_init, data_in);
            crc_valid <= 1'b1;
        end else begin
            crc_valid <= 1'b0;
        end
    end
    
    assign crc_out = crc_reg;
    
    // Compute CRC64 for 256-bit data
    function [63:0] compute_crc64_256;
        input [63:0] crc;
        input [255:0] data;
        integer i;
        reg [63:0] temp_crc;
        begin
            temp_crc = crc;
            
            // Process 4 chunks of 64-bit data sequentially
            for (i = 0; i < 4; i = i + 1) begin
                temp_crc = compute_crc64_64bit(temp_crc, data[(i+1)*64-1:i*64]);
            end
            
            compute_crc64_256 = temp_crc;
        end
    endfunction
    
    // Compute CRC64 for 64-bit data chunk
    function [63:0] compute_crc64_64bit;
        input [63:0] crc;
        input [63:0] data;
        integer i;
        reg [63:0] d;
        begin
            d = data ^ crc;
            for (i = 0; i < 64; i = i + 1) begin
                if (d[0]) begin
                    d = (d >> 1) ^ POLY;
                end else begin
                    d = d >> 1;
                end
            end
            compute_crc64_64bit = d;
        end
    endfunction
    
endmodule
