// MD5 Hash Core with Deep Pipeline for Block-Level Pipelining
// Supports multiple blocks processing in pipeline stages

module md5_core_deep_pipeline (
    input wire         clk,
    input wire         rst_n,
    
    // Block input
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    input wire         block_last,  // Last block of message
    
    // Hash output (only valid when processing last block)
    output reg [127:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    
    // Control
    input wire         start,      // Start new hash computation
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
    
    // Pipeline depth: 8 stages (each stage processes 8 rounds)
    parameter PIPELINE_DEPTH = 8;
    parameter ROUNDS_PER_STAGE = 8;
    
    // MD5 state registers (persistent across blocks)
    reg [31:0] h0, h1, h2, h3;
    
    // Pipeline registers for block processing
    reg [511:0] block_pipe [0:PIPELINE_DEPTH-1];
    reg [31:0]  w_pipe [0:PIPELINE_DEPTH-1] [0:15];  // Words for each pipeline stage
    reg [31:0]  a_pipe [0:PIPELINE_DEPTH], b_pipe [0:PIPELINE_DEPTH], 
                c_pipe [0:PIPELINE_DEPTH], d_pipe [0:PIPELINE_DEPTH];
    reg [5:0]   round_start [0:PIPELINE_DEPTH-1];  // Starting round for each stage
    reg         valid_pipe [0:PIPELINE_DEPTH];
    reg         last_pipe [0:PIPELINE_DEPTH];
    
    // Pipeline control
    reg [2:0]   pipeline_head;  // Next stage to fill
    reg [2:0]   pipeline_tail;   // Stage being processed
    reg         pipeline_full;
    reg         pipeline_empty;
    
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
    
    // Extract word index for MD5 rounds
    function [3:0] get_w_index;
        input [5:0] round;
        input [1:0] phase;
        reg [3:0] idx;
        begin
            case (phase)
                2'b00: idx = round[3:0];  // Rounds 0-15
                2'b01: idx = ((round[3:0] * 5) + 1) & 4'hF;  // Rounds 16-31
                2'b10: idx = ((round[3:0] * 3) + 5) & 4'hF;  // Rounds 32-47
                2'b11: idx = (round[3:0] * 7) & 4'hF;  // Rounds 48-63
            endcase
            get_w_index = idx;
        end
    endfunction
    
    // Process 8 rounds in one pipeline stage
    function [127:0] process_rounds;
        input [31:0] a_in, b_in, c_in, d_in;
        input [5:0] start_round;
        input [511:0] block_words;
        integer i;
        reg [31:0] a, b, c, d, a_next, b_next, c_next, d_next;
        reg [31:0] round_temp;
        reg [3:0] w_idx;
        reg [31:0] w [0:15];
        begin
            // Extract words
            for (i = 0; i < 16; i = i + 1) begin
                w[i] = block_words[i*32 +: 32];
            end
            
            a = a_in;
            b = b_in;
            c = c_in;
            d = d_in;
            
            // Process 8 rounds
            for (i = 0; i < ROUNDS_PER_STAGE; i = i + 1) begin
                w_idx = get_w_index(start_round + i, (start_round + i) >> 4);
                
                case ((start_round + i) >> 4)
                    2'b00: round_temp = a + F(b, c, d) + w[w_idx] + K[start_round + i];
                    2'b01: round_temp = a + G(b, c, d) + w[w_idx] + K[start_round + i];
                    2'b10: round_temp = a + H(b, c, d) + w[w_idx] + K[start_round + i];
                    2'b11: round_temp = a + I(b, c, d) + w[w_idx] + K[start_round + i];
                endcase
                
                a_next = b + rotate_left(round_temp, S[start_round + i]);
                b_next = a;
                c_next = b;
                d_next = c;
                
                a = a_next;
                b = b_next;
                c = c_next;
                d = d_next;
            end
            
            process_rounds = {d, c, b, a};
        end
    endfunction
    
    // Pipeline status
    always @(*) begin
        pipeline_full = ((pipeline_head + 1) % PIPELINE_DEPTH == pipeline_tail);
        pipeline_empty = (pipeline_head == pipeline_tail) && !valid_pipe[pipeline_tail];
        block_ready = !pipeline_full;
    end
    
    // Main pipeline processing
    integer stage;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0 <= 32'h67452301;
            h1 <= 32'hefcdab89;
            h2 <= 32'h98badcfe;
            h3 <= 32'h10325476;
            
            pipeline_head <= 3'b0;
            pipeline_tail <= 3'b0;
            
            for (stage = 0; stage < PIPELINE_DEPTH; stage = stage + 1) begin
                block_pipe[stage] <= 512'b0;
                valid_pipe[stage] <= 1'b0;
                last_pipe[stage] <= 1'b0;
                round_start[stage] <= 6'b0;
            end
            
            for (stage = 0; stage <= PIPELINE_DEPTH; stage = stage + 1) begin
                a_pipe[stage] <= 32'b0;
                b_pipe[stage] <= 32'b0;
                c_pipe[stage] <= 32'b0;
                d_pipe[stage] <= 32'b0;
                valid_pipe[stage] <= 1'b0;
                last_pipe[stage] <= 1'b0;
            end
            
            hash_valid <= 1'b0;
            ready <= 1'b0;
        end else begin
            // Input stage: Accept new block
            if (block_valid && block_ready && !pipeline_full) begin
                block_pipe[pipeline_head] <= block_data;
                round_start[pipeline_head] <= 6'b0;
                valid_pipe[pipeline_head] <= 1'b1;
                last_pipe[pipeline_head] <= block_last;
                pipeline_head <= (pipeline_head + 1) % PIPELINE_DEPTH;
            end
            
            // Initialize first stage with hash state
            if (valid_pipe[pipeline_tail] && !valid_pipe[pipeline_tail + 1]) begin
                a_pipe[pipeline_tail] <= h0;
                b_pipe[pipeline_tail] <= h1;
                c_pipe[pipeline_tail] <= h2;
                d_pipe[pipeline_tail] <= h3;
            end
            
            // Pipeline stages: Process rounds
            for (stage = 0; stage < PIPELINE_DEPTH; stage = stage + 1) begin
                if (valid_pipe[stage]) begin
                    // Process 8 rounds
                    reg [127:0] result;
                    result = process_rounds(
                        a_pipe[stage], b_pipe[stage], c_pipe[stage], d_pipe[stage],
                        round_start[stage],
                        block_pipe[stage]
                    );
                    
                    a_pipe[stage + 1] <= result[31:0];
                    b_pipe[stage + 1] <= result[63:32];
                    c_pipe[stage + 1] <= result[95:64];
                    d_pipe[stage + 1] <= result[127:96];
                    valid_pipe[stage + 1] <= valid_pipe[stage];
                    last_pipe[stage + 1] <= last_pipe[stage];
                    
                    // Move to next stage
                    if (round_start[stage] + ROUNDS_PER_STAGE >= 64) begin
                        // This stage completed all rounds
                        valid_pipe[stage] <= 1'b0;
                    end else begin
                        round_start[stage] <= round_start[stage] + ROUNDS_PER_STAGE;
                    end
                end
            end
            
            // Output stage: Update hash state
            if (valid_pipe[PIPELINE_DEPTH] && last_pipe[PIPELINE_DEPTH]) begin
                // Last block, output final hash
                h0 <= h0 + a_pipe[PIPELINE_DEPTH];
                h1 <= h1 + b_pipe[PIPELINE_DEPTH];
                h2 <= h2 + c_pipe[PIPELINE_DEPTH];
                h3 <= h3 + d_pipe[PIPELINE_DEPTH];
                hash_out <= {h3 + d_pipe[PIPELINE_DEPTH], h2 + c_pipe[PIPELINE_DEPTH], 
                            h1 + b_pipe[PIPELINE_DEPTH], h0 + a_pipe[PIPELINE_DEPTH]};
                hash_valid <= 1'b1;
                valid_pipe[PIPELINE_DEPTH] <= 1'b0;
            end else if (valid_pipe[PIPELINE_DEPTH]) begin
                // Intermediate block, update state
                h0 <= h0 + a_pipe[PIPELINE_DEPTH];
                h1 <= h1 + b_pipe[PIPELINE_DEPTH];
                h2 <= h2 + c_pipe[PIPELINE_DEPTH];
                h3 <= h3 + d_pipe[PIPELINE_DEPTH];
                valid_pipe[PIPELINE_DEPTH] <= 1'b0;
                pipeline_tail <= (pipeline_tail + 1) % PIPELINE_DEPTH;
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
