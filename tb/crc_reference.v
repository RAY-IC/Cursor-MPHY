// Reference CRC calculation functions for testbench verification
// These functions provide software reference implementations

module crc_reference;

    // CRC32 reference calculation
    function [31:0] crc32_ref;
        input [7:0] data [];
        input integer len;
        integer i, j;
        reg [31:0] crc;
        reg [31:0] poly;
        begin
            poly = 32'hEDB88320;  // Reversed polynomial
            crc = 32'hFFFFFFFF;
            
            for (i = 0; i < len; i = i + 1) begin
                crc = crc ^ {24'b0, data[i]};
                for (j = 0; j < 8; j = j + 1) begin
                    if (crc[0]) begin
                        crc = (crc >> 1) ^ poly;
                    end else begin
                        crc = crc >> 1;
                    end
                end
            end
            
            crc32_ref = ~crc;
        end
    endfunction
    
    // CRC32C reference calculation
    function [31:0] crc32c_ref;
        input [7:0] data [];
        input integer len;
        integer i, j;
        reg [31:0] crc;
        reg [31:0] poly;
        begin
            poly = 32'h82F63B78;  // Reversed polynomial
            crc = 32'hFFFFFFFF;
            
            for (i = 0; i < len; i = i + 1) begin
                crc = crc ^ {24'b0, data[i]};
                for (j = 0; j < 8; j = j + 1) begin
                    if (crc[0]) begin
                        crc = (crc >> 1) ^ poly;
                    end else begin
                        crc = crc >> 1;
                    end
                end
            end
            
            crc32c_ref = ~crc;
        end
    endfunction
    
    // CRC64 reference calculation
    function [63:0] crc64_ref;
        input [7:0] data [];
        input integer len;
        integer i, j;
        reg [63:0] crc;
        reg [63:0] poly;
        begin
            poly = 64'hC96C5795D7870F42;  // Reversed polynomial
            crc = 64'hFFFFFFFFFFFFFFFF;
            
            for (i = 0; i < len; i = i + 1) begin
                crc = crc ^ {56'b0, data[i]};
                for (j = 0; j < 8; j = j + 1) begin
                    if (crc[0]) begin
                        crc = (crc >> 1) ^ poly;
                    end else begin
                        crc = crc >> 1;
                    end
                end
            end
            
            crc64_ref = ~crc;
        end
    endfunction

endmodule
