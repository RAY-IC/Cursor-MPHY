// MD5 Hash Core Module
// Implements MD5 algorithm with pipeline optimization

module md5_core (
    input wire         clk,
    input wire         rst_n,
    
    // Block input
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    
    // Hash output
    output reg [127:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    
    // Control
    input wire         start,
    output reg         done
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
    
    // MD5 state registers
    reg [31:0] h0, h1, h2, h3;
    reg [31:0] a, b, c, d;
    reg [31:0] a_next, b_next, c_next, d_next;
    reg [31:0] round_temp;  // Temporary variable for round computation
    reg [3:0]  w_idx;  // Word index for MD5 round computation
    
    // Pipeline registers
    reg [511:0] block_reg;
    reg [31:0]  w [0:15];
    reg [5:0]   round_counter;
    reg [1:0]   state;  // 0: idle, 1: processing, 2: updating
    
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
    
    // Extract words from block
    always @(*) begin
        w[0] = block_reg[31:0];
        w[1] = block_reg[63:32];
        w[2] = block_reg[95:64];
        w[3] = block_reg[127:96];
        w[4] = block_reg[159:128];
        w[5] = block_reg[191:160];
        w[6] = block_reg[223:192];
        w[7] = block_reg[255:224];
        w[8] = block_reg[287:256];
        w[9] = block_reg[319:288];
        w[10] = block_reg[351:320];
        w[11] = block_reg[383:352];
        w[12] = block_reg[415:384];
        w[13] = block_reg[447:416];
        w[14] = block_reg[479:448];
        w[15] = block_reg[511:480];
    end
    
    // Main processing loop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0 <= 32'h67452301;
            h1 <= 32'hefcdab89;
            h2 <= 32'h98badcfe;
            h3 <= 32'h10325476;
            a <= 32'h67452301;
            b <= 32'hefcdab89;
            c <= 32'h98badcfe;
            d <= 32'h10325476;
            round_counter <= 6'b0;
            state <= 2'b0;
            block_ready <= 1'b1;
            hash_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                2'b00: begin  // Idle
                    if (block_valid && block_ready) begin
                        block_reg <= block_data;
                        a <= h0;
                        b <= h1;
                        c <= h2;
                        d <= h3;
                        round_counter <= 6'b0;
                        state <= 2'b01;
                        block_ready <= 1'b0;
                    end
                end
                2'b01: begin  // Processing 64 rounds
                    if (round_counter < 64) begin
                        // Round computation - MD5 uses specific word selection per round
                        case (round_counter[5:4])
                            2'b00: begin  // Rounds 0-15: F function, use w[i] where i = round_counter
                                round_temp = a + F(b, c, d) + w[round_counter[3:0]] + K[round_counter];
                                a_next = b + rotate_left(round_temp, S[round_counter]);
                            end
                            2'b01: begin  // Rounds 16-31: G function, use w[(5*i+1) mod 16]
                                w_idx = ((round_counter[3:0] * 5) + 1) & 4'hF;  // mod 16
                                round_temp = a + G(b, c, d) + w[w_idx] + K[round_counter];
                                a_next = b + rotate_left(round_temp, S[round_counter]);
                            end
                            2'b10: begin  // Rounds 32-47: H function, use w[(3*i+5) mod 16]
                                w_idx = ((round_counter[3:0] * 3) + 5) & 4'hF;  // mod 16
                                round_temp = a + H(b, c, d) + w[w_idx] + K[round_counter];
                                a_next = b + rotate_left(round_temp, S[round_counter]);
                            end
                            2'b11: begin  // Rounds 48-63: I function, use w[(7*i) mod 16]
                                w_idx = (round_counter[3:0] * 7) & 4'hF;  // mod 16
                                round_temp = a + I(b, c, d) + w[w_idx] + K[round_counter];
                                a_next = b + rotate_left(round_temp, S[round_counter]);
                            end
                        endcase
                        
                        // Update registers
                        d <= c;
                        c <= b;
                        b <= a;
                        a <= a_next;
                        round_counter <= round_counter + 1;
                    end else begin
                        // All rounds done, update hash state
                        state <= 2'b10;
                    end
                end
                2'b10: begin  // Update hash state
                    h0 <= h0 + a;
                    h1 <= h1 + b;
                    h2 <= h2 + c;
                    h3 <= h3 + d;
                    hash_out <= {h3 + d, h2 + c, h1 + b, h0 + a};
                    hash_valid <= 1'b1;
                    done <= 1'b1;
                    state <= 2'b00;
                    block_ready <= 1'b1;
                end
            endcase
            
            if (hash_valid && hash_ready) begin
                hash_valid <= 1'b0;
                done <= 1'b0;
            end
        end
    end

endmodule
