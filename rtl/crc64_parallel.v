// CRC64 Parallel Calculation Module
// Polynomial: 0x42F0E1EBA9EA3693 (ECMA-182)
// Processes 64-bit data chunks in parallel

module crc64_parallel (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [63:0] data_in,
    input  wire [63:0] crc_init,
    output reg  [63:0] crc_out,
    output reg         crc_valid
);

    // CRC64 polynomial: 0x42F0E1EBA9EA3693
    // Reversed polynomial for hardware: 0xC96C5795D7870F42
    localparam [63:0] POLY = 64'hC96C5795D7870F42;
    
    reg [63:0] crc_reg;
    reg [63:0] data_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            crc_reg <= crc_init;
            crc_valid <= 1'b0;
        end else if (enable) begin
            data_reg <= data_in;
            crc_reg <= next_crc64(crc_reg, data_in);
            crc_valid <= 1'b1;
        end else begin
            crc_valid <= 1'b0;
        end
    end
    
    assign crc_out = crc_reg;
    
    // CRC64 calculation function for 64-bit data
    function [63:0] next_crc64;
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
            next_crc64 = d;
        end
    endfunction
    
endmodule
