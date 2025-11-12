// Block Formatter Module
// Handles padding and length encoding for hash algorithms

module block_formatter (
    input wire         clk,
    input wire         rst_n,
    
    // Input from AXI interface
    input wire [511:0] block_in,
    input wire         block_valid,
    output reg         block_ready,
    input wire         block_last,
    
    // Output to hash core
    output reg [511:0] block_out,
    output reg         block_out_valid,
    input wire         block_out_ready,
    
    // Control
    input wire [1:0]   algorithm_sel,  // 00: MD5, 01: SHA256, 10: SHA1
    input wire [63:0]  total_length,   // Total message length in bits
    
    output reg         formatting_done
);

    reg [511:0] padded_block;
    reg [63:0]  message_length;
    reg         padding_state;  // 0: receiving, 1: padding
    
    // Padding logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            block_out <= 512'b0;
            block_out_valid <= 1'b0;
            block_ready <= 1'b1;
            padding_state <= 1'b0;
            message_length <= 64'b0;
            formatting_done <= 1'b0;
        end else begin
            if (block_valid && block_ready) begin
                if (block_last) begin
                    // Last block - need padding
                    message_length <= total_length;
                    // Add padding: 1 bit + zeros + length
                    padded_block <= block_in;
                    // Find the position for '1' bit
                    // For simplicity, assume we add padding in the next cycle
                    padding_state <= 1'b1;
                    block_ready <= 1'b0;
                end else begin
                    // Not last block, pass through
                    block_out <= block_in;
                    block_out_valid <= 1'b1;
                end
            end
            
            if (padding_state) begin
                // Apply padding
                // Padding format: ...data... 1 000...000 length(64bit)
                // Find first zero bit after data
                // For MD5/SHA256/SHA1: padding starts with bit '1'
                // Then zeros until 448 bits (MD5/SHA256) or 512-64-1 bits
                // Then 64-bit length
                
                // Simplified: assume block_in has space for padding
                // In real implementation, need to track actual data length
                padded_block[511:448] <= message_length[63:0];  // Length in last 64 bits
                padded_block[447] <= 1'b1;  // Padding bit
                padded_block[446:0] <= block_in[446:0];  // Original data
                
                block_out <= padded_block;
                block_out_valid <= 1'b1;
                padding_state <= 1'b0;
                formatting_done <= 1'b1;
            end
            
            if (block_out_valid && block_out_ready) begin
                block_out_valid <= 1'b0;
                block_ready <= 1'b1;
                formatting_done <= 1'b0;
            end
        end
    end

endmodule
