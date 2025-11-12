// CRC32C Parallel Calculation Module
// Polynomial: 0x1EDC6F41 (Castagnoli)
// Processes 32-bit data chunks in parallel

module crc32c_parallel (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire [31:0] data_in,
    input  wire [31:0] crc_init,
    output reg  [31:0] crc_out,
    output reg         crc_valid
);

    // CRC32C polynomial: 0x1EDC6F41
    // Reversed polynomial for hardware: 0x82F63B78
    localparam [31:0] POLY = 32'h82F63B78;
    
    reg [31:0] crc_reg;
    reg [31:0] data_reg;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            crc_reg <= crc_init;
            crc_valid <= 1'b0;
        end else if (enable) begin
            data_reg <= data_in;
            crc_reg <= next_crc32c(crc_reg, data_in);
            crc_valid <= 1'b1;
        end else begin
            crc_valid <= 1'b0;
        end
    end
    
    assign crc_out = crc_reg;
    
    // CRC32C calculation function for 32-bit data
    function [31:0] next_crc32c;
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
            next_crc32c = d;
        end
    endfunction
    
endmodule
