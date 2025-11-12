// Optimized MD5 Hash Core with Reduced Pipeline Depth
// Pipeline depth: 3 blocks (reduced from 4)
// Uses shared constants ROM

module md5_core_optimized (
    input wire         clk,
    input wire         rst_n,
    
    // Block input
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    input wire         block_last,
    
    // Hash output
    output reg [127:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    
    // Shared constants interface
    input wire [31:0]  k_const,  // From shared ROM
    input wire [4:0]   s_const,  // From shared ROM
    output reg [5:0]   round_addr,  // To shared ROM
    
    // Control
    input wire         start,
    output reg         ready
);

    // Reduced pipeline depth: 3 blocks
    parameter BLOCK_PIPELINE_DEPTH = 3;
    
    // MD5 state (persistent)
    reg [31:0] h0, h1, h2, h3;
    
    // Block pipeline: store blocks being processed
    reg [511:0] block_buffer [0:BLOCK_PIPELINE_DEPTH-1];
    reg [31:0]  block_h0 [0:BLOCK_PIPELINE_DEPTH-1];
    reg [31:0]  block_h1 [0:BLOCK_PIPELINE_DEPTH-1];
    reg [31:0]  block_h2 [0:BLOCK_PIPELINE_DEPTH-1];
    reg [31:0]  block_h3 [0:BLOCK_PIPELINE_DEPTH-1];
    reg [5:0]   block_round [0:BLOCK_PIPELINE_DEPTH-1];
    reg         block_valid [0:BLOCK_PIPELINE_DEPTH-1];
    reg         block_last_flag [0:BLOCK_PIPELINE_DEPTH-1];
    reg         block_done [0:BLOCK_PIPELINE_DEPTH-1];
    
    // Temporary variables for round computation (combinational)
    wire [31:0] round_temp [0:BLOCK_PIPELINE_DEPTH-1];
    wire [3:0]  w_idx [0:BLOCK_PIPELINE_DEPTH-1];
    wire [31:0] w_val [0:BLOCK_PIPELINE_DEPTH-1];
    wire [31:0] a_next [0:BLOCK_PIPELINE_DEPTH-1];
    
    // Input slot finder
    wire [1:0]  empty_slot;
    wire        found_empty;
    
    // MD5 functions
    function [31:0] F;
        input [31:0] x, y, z;
        F = (x & y) | (~x & z);
    endfunction
    
    function [31:0] G;
        input [31:0] x, y, z;
        G = (x & z) | (y & ~z);
    endfunction
    
    function [31:0] H;
        input [31:0] x, y, z;
        H = x ^ y ^ z;
    endfunction
    
    function [31:0] I;
        input [31:0] x, y, z;
        I = y ^ (x | ~z);
    endfunction
    
    function [31:0] rotate_left;
        input [31:0] value;
        input [4:0]  amount;
        rotate_left = (value << amount) | (value >> (32 - amount));
    endfunction
    
    // Extract word from block
    function [31:0] get_word;
        input [511:0] block;
        input [3:0]   word_idx;
        get_word = block[word_idx*32 +: 32];
    endfunction
    
    // Get word index for MD5 round
    function [3:0] get_w_index;
        input [5:0] round;
        reg [3:0] idx;
        begin
            case (round[5:4])
                2'b00: idx = round[3:0];
                2'b01: idx = ((round[3:0] * 5) + 1) & 4'hF;
                2'b10: idx = ((round[3:0] * 3) + 5) & 4'hF;
                2'b11: idx = (round[3:0] * 7) & 4'hF;
            endcase
            get_w_index = idx;
        end
    endfunction
    
    // Pipeline control
    reg pipeline_has_space;
    always @(*) begin
        pipeline_has_space = !block_valid[0] || !block_valid[1] || !block_valid[2];
        block_ready = pipeline_has_space && ready;
    end
    
    // Find empty slot (combinational)
    assign found_empty = !block_valid[0] || !block_valid[1] || !block_valid[2];
    assign empty_slot = !block_valid[0] ? 2'b0 :
                       !block_valid[1] ? 2'b01 : 2'b10;
    
    // Round computation (combinational for each pipeline slot)
    // Note: Uses shared constants from ROM (k_const, s_const)
    genvar j;
    generate
        for (j = 0; j < BLOCK_PIPELINE_DEPTH; j = j + 1) begin : round_comp
            assign w_idx[j] = get_w_index(block_round[j]);
            assign w_val[j] = get_word(block_buffer[j], w_idx[j]);
            
            // Use shared constants (need to register round_addr for ROM access)
            // For now, use local computation with shared constants
            assign round_temp[j] = (block_valid[j] && block_round[j] < 64) ? (
                                   (block_round[j][5:4] == 2'b00) ? 
                                   (block_h0[j] + F(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + k_const) :
                                   (block_round[j][5:4] == 2'b01) ?
                                   (block_h0[j] + G(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + k_const) :
                                   (block_round[j][5:4] == 2'b10) ?
                                   (block_h0[j] + H(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + k_const) :
                                   (block_h0[j] + I(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + k_const)
                                   ) : 32'b0;
            
            assign a_next[j] = (block_valid[j] && block_round[j] < 64) ? 
                               (block_h1[j] + rotate_left(round_temp[j], s_const)) : 32'b0;
        end
    endgenerate
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0 <= 32'h67452301;
            h1 <= 32'hefcdab89;
            h2 <= 32'h98badcfe;
            h3 <= 32'h10325476;
            
            for (i = 0; i < BLOCK_PIPELINE_DEPTH; i = i + 1) begin
                block_buffer[i] <= 512'b0;
                block_h0[i] <= 32'b0;
                block_h1[i] <= 32'b0;
                block_h2[i] <= 32'b0;
                block_h3[i] <= 32'b0;
                block_round[i] <= 6'b0;
                block_valid[i] <= 1'b0;
                block_last_flag[i] <= 1'b0;
                block_done[i] <= 1'b0;
            end
            
            hash_valid <= 1'b0;
            ready <= 1'b1;
            round_addr <= 6'b0;
        end else begin
            // Input: Accept new block into pipeline
            if (block_valid && block_ready && found_empty) begin
                block_buffer[empty_slot] <= block_data;
                block_h0[empty_slot] <= h0;
                block_h1[empty_slot] <= h1;
                block_h2[empty_slot] <= h2;
                block_h3[empty_slot] <= h3;
                block_round[empty_slot] <= 6'b0;
                block_valid[empty_slot] <= 1'b1;
                block_last_flag[empty_slot] <= block_last;
            end
            
            // Request constants from shared ROM (use first active block's round)
            if (block_valid[0]) begin
                round_addr <= block_round[0];
            end else if (block_valid[1]) begin
                round_addr <= block_round[1];
            end else if (block_valid[2]) begin
                round_addr <= block_round[2];
            end
            
            // Process all blocks in pipeline (one round per cycle)
            for (i = 0; i < BLOCK_PIPELINE_DEPTH; i = i + 1) begin
                if (block_valid[i] && block_round[i] < 64) begin
                    // Process one round (using combinational signals)
                    block_h0[i] <= a_next[i];
                    block_h1[i] <= block_h0[i];
                    block_h2[i] <= block_h1[i];
                    block_h3[i] <= block_h2[i];
                    block_round[i] <= block_round[i] + 1;
                end else if (block_valid[i] && block_round[i] == 64) begin
                    // Block processing complete - mark as done
                    block_done[i] <= 1'b1;
                    block_valid[i] <= 1'b0;
                end
            end
            
            // Sequential hash state update (ensure order)
            if (block_done[0]) begin
                // Slot 0 completed
                if (block_last_flag[0]) begin
                    hash_out <= {h3 + block_h3[0], h2 + block_h2[0], 
                                h1 + block_h1[0], h0 + block_h0[0]};
                    hash_valid <= 1'b1;
                end else begin
                    h0 <= h0 + block_h0[0];
                    h1 <= h1 + block_h1[0];
                    h2 <= h2 + block_h2[0];
                    h3 <= h3 + block_h3[0];
                end
                block_done[0] <= 1'b0;
            end else if (block_done[1] && !block_done[0]) begin
                // Slot 1 completed
                if (block_last_flag[1]) begin
                    hash_out <= {h3 + block_h3[1], h2 + block_h2[1], 
                                h1 + block_h1[1], h0 + block_h0[1]};
                    hash_valid <= 1'b1;
                end else begin
                    h0 <= h0 + block_h0[1];
                    h1 <= h1 + block_h1[1];
                    h2 <= h2 + block_h2[1];
                    h3 <= h3 + block_h3[1];
                end
                block_done[1] <= 1'b0;
            end else if (block_done[2] && !block_done[0] && !block_done[1]) begin
                // Slot 2 completed
                if (block_last_flag[2]) begin
                    hash_out <= {h3 + block_h3[2], h2 + block_h2[2], 
                                h1 + block_h1[2], h0 + block_h0[2]};
                    hash_valid <= 1'b1;
                end else begin
                    h0 <= h0 + block_h0[2];
                    h1 <= h1 + block_h1[2];
                    h2 <= h2 + block_h2[2];
                    h3 <= h3 + block_h3[2];
                end
                block_done[2] <= 1'b0;
            end
            
            if (hash_valid && hash_ready) begin
                hash_valid <= 1'b0;
                // Reset for next message
                h0 <= 32'h67452301;
                h1 <= 32'hefcdab89;
                h2 <= 32'h98badcfe;
                h3 <= 32'h10325476;
            end
            
            ready <= 1'b1;
        end
    end

endmodule
