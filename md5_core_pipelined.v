// MD5 Hash Core with Block-Level Pipelining
// Supports multiple blocks processing in pipeline (iterative with pipeline stages)

module md5_core_pipelined (
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
    
    // Control
    input wire         start,
    output reg         ready
);

    // MD5 constants
    parameter [31:0] K [0:63] = '{
        32'hd76aa478, 32'he8c7b756, 32'h242070db, 32'hc1bdceee,
        32'hf57c0faf, 32'h4787c62a, 32'ha8304613, 32'hfd469501,
        32'h698098d8, 32'h8b44f7af, 32'hffff5bb1, 32'h895cd7be,
        32'h6b901122, 32'hfd987193, 32'ha679438e, 32'h49b40821,
        32'hf61e2562, 32'hc040b340, 32'h265e5a51, 32'he9b6c7aa,
        32'hd62f105d, 32'h02441453, 32'hd8a1e681, 32'he7d3fbc8,
        32'h21e1cde6, 32'hc33707d6, 32'hf4d50d87, 32'h455a14ed,
        32'ha9e3e905, 32'hfcefa3f8, 32'h676f02d9, 32'h8d2a4c8a,
        32'hfffa3942, 32'h8771f681, 32'h6d9d6122, 32'hfde5380c,
        32'ha4beea44, 32'h4bdecfa9, 32'hf6bb4b60, 32'hbebfbc70,
        32'h289b7ec6, 32'heaa127fa, 32'hd4ef3085, 32'h04881d05,
        32'hd9d4d039, 32'he6db99e5, 32'h1fa27cf8, 32'hc4ac5665,
        32'hf4292244, 32'h432aff97, 32'hab9423a7, 32'hfc93a039,
        32'hd655b1c3, 32'h8f0ccc92, 32'hffeff47d, 32'h85845dd1,
        32'h6fa87e4f, 32'hfe2ce6e0, 32'ha3014314, 32'h4e0811a1,
        32'hf7537e82, 32'hbd3af235, 32'h2ad7d2bb, 32'heb86d391
    };
    
    parameter [4:0] S [0:63] = '{
        5'd7, 5'd12, 5'd17, 5'd22, 5'd7, 5'd12, 5'd17, 5'd22,
        5'd7, 5'd12, 5'd17, 5'd22, 5'd7, 5'd12, 5'd17, 5'd22,
        5'd5, 5'd9, 5'd14, 5'd20, 5'd5, 5'd9, 5'd14, 5'd20,
        5'd5, 5'd9, 5'd14, 5'd20, 5'd5, 5'd9, 5'd14, 5'd20,
        5'd4, 5'd11, 5'd16, 5'd23, 5'd4, 5'd11, 5'd16, 5'd23,
        5'd4, 5'd11, 5'd16, 5'd23, 5'd4, 5'd11, 5'd16, 5'd23,
        5'd6, 5'd10, 5'd15, 5'd21, 5'd6, 5'd10, 5'd15, 5'd21,
        5'd6, 5'd10, 5'd15, 5'd21, 5'd6, 5'd10, 5'd15, 5'd21
    };
    
    // Pipeline depth: support 4 blocks in pipeline
    parameter BLOCK_PIPELINE_DEPTH = 4;
    
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
    reg         block_done [0:BLOCK_PIPELINE_DEPTH-1];  // Completion flag
    
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
        pipeline_has_space = !block_valid[0] || !block_valid[1] || 
                            !block_valid[2] || !block_valid[3];
        block_ready = pipeline_has_space && ready;
    end
    
    // Find empty slot (combinational)
    assign found_empty = !block_valid[0] || !block_valid[1] || 
                        !block_valid[2] || !block_valid[3];
    assign empty_slot = !block_valid[0] ? 2'b0 :
                       !block_valid[1] ? 2'b01 :
                       !block_valid[2] ? 2'b10 : 2'b11;
    
    // Round computation (combinational for each pipeline slot)
    genvar j;
    generate
        for (j = 0; j < BLOCK_PIPELINE_DEPTH; j = j + 1) begin : round_comp
            assign w_idx[j] = get_w_index(block_round[j]);
            assign w_val[j] = get_word(block_buffer[j], w_idx[j]);
            
            assign round_temp[j] = (block_valid[j] && block_round[j] < 64) ? (
                                   (block_round[j][5:4] == 2'b00) ? 
                                   (block_h0[j] + F(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + K[block_round[j]]) :
                                   (block_round[j][5:4] == 2'b01) ?
                                   (block_h0[j] + G(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + K[block_round[j]]) :
                                   (block_round[j][5:4] == 2'b10) ?
                                   (block_h0[j] + H(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + K[block_round[j]]) :
                                   (block_h0[j] + I(block_h1[j], block_h2[j], block_h3[j]) + w_val[j] + K[block_round[j]])
                                   ) : 32'b0;
            
            assign a_next[j] = (block_valid[j] && block_round[j] < 64) ? 
                               (block_h1[j] + rotate_left(round_temp[j], S[block_round[j]])) : 32'b0;
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
            // Process completed blocks in order (slot 0 first, then 1, 2, 3)
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
                // Slot 1 completed (only if slot 0 is not done)
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
            end else if (block_done[3] && !block_done[0] && !block_done[1] && !block_done[2]) begin
                // Slot 3 completed
                if (block_last_flag[3]) begin
                    hash_out <= {h3 + block_h3[3], h2 + block_h2[3], 
                                h1 + block_h1[3], h0 + block_h0[3]};
                    hash_valid <= 1'b1;
                end else begin
                    h0 <= h0 + block_h0[3];
                    h1 <= h1 + block_h1[3];
                    h2 <= h2 + block_h2[3];
                    h3 <= h3 + block_h3[3];
                end
                block_done[3] <= 1'b0;
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
