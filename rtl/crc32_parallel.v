// CRC32 Parallel Calculation Module
// Polynomial: 0x04C11DB7 (IEEE 802.3)
// Processes 32-bit data chunks in parallel

module crc32_parallel (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [31:0] data_in,
    input  wire [31:0] crc_init,
    output reg  [31:0] crc_out,
    output reg         crc_valid
);

    // CRC32 polynomial: 0x04C11DB7
    // Reversed polynomial for hardware: 0xEDB88320
    localparam [31:0] POLY = 32'hEDB88320;
    
    reg [31:0] crc_reg;
    reg [31:0] data_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            crc_reg <= crc_init;
            crc_valid <= 1'b0;
        end else if (enable) begin
            data_reg <= data_in;
            crc_reg <= next_crc32(crc_reg, data_in);
            crc_valid <= 1'b1;
        end else begin
            crc_valid <= 1'b0;
        end
    end
    
    assign crc_out = crc_reg;
    
    // CRC32 calculation function for 32-bit data
    function [31:0] next_crc32;
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
            next_crc32 = d;
        end
    endfunction
    
endmodule
