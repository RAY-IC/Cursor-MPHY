// SHA1 Hash Core Module
// Implements SHA1 algorithm with pipeline optimization

module sha1_core (
    input wire         clk,
    input wire         rst_n,
    
    // Block input
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    
    // Hash output
    output reg [159:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    
    // Control
    input wire         start,
    output reg         done
);

    // SHA1 state registers
    reg [31:0] h0, h1, h2, h3, h4;
    reg [31:0] a, b, c, d, e;
    reg [31:0] a_next, b_next, c_next, d_next, e_next;
    reg [31:0] f_result, k_const, temp;  // Temporary variables for round computation
    
    // Message schedule W[0..79]
    reg [31:0] w [0:79];
    
    // Pipeline registers
    reg [511:0] block_reg;
    reg [6:0]   round_counter;
    reg [1:0]   state;  // 0: idle, 1: message expansion, 2: main loop, 3: update
    
    // SHA1 functions
    function [31:0] f0;
        input [31:0] x, y, z;
        f0 = (x & y) | (~x & z);
    endfunction
    
    function [31:0] f1;
        input [31:0] x, y, z;
        f1 = x ^ y ^ z;
    endfunction
    
    function [31:0] f2;
        input [31:0] x, y, z;
        f2 = (x & y) | (x & z) | (y & z);
    endfunction
    
    function [31:0] rotate_left;
        input [31:0] value;
        input [4:0]  amount;
        rotate_left = (value << amount) | (value >> (32 - amount));
    endfunction
    
    // Extract initial words from block
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
    
    // Main processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h0 <= 32'h67452301;
            h1 <= 32'hefcdab89;
            h2 <= 32'h98badcfe;
            h3 <= 32'h10325476;
            h4 <= 32'hc3d2e1f0;
            a <= 32'h67452301;
            b <= 32'hefcdab89;
            c <= 32'h98badcfe;
            d <= 32'h10325476;
            e <= 32'hc3d2e1f0;
            round_counter <= 7'b0;
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
                        e <= h4;
                        round_counter <= 7'b0;
                        state <= 2'b01;  // Start message expansion
                        block_ready <= 1'b0;
                    end
                end
                2'b01: begin  // Message expansion: compute W[16..79]
                    if (round_counter < 16) begin
                        // W[0..15] already set from block
                        round_counter <= round_counter + 1;
                    end else if (round_counter < 80) begin
                        // Compute W[i] = ROTL^1(W[i-3] XOR W[i-8] XOR W[i-14] XOR W[i-16])
                        w[round_counter] <= rotate_left(w[round_counter-3] ^ w[round_counter-8] ^ 
                                                        w[round_counter-14] ^ w[round_counter-16], 5'd1);
                        round_counter <= round_counter + 1;
                    end else begin
                        // Message expansion done, start main loop
                        round_counter <= 7'b0;
                        state <= 2'b10;
                    end
                end
                2'b10: begin  // Main loop: 80 rounds
                    if (round_counter < 80) begin
                        // Select function and constant based on round
                        if (round_counter < 20) begin
                            f_result = f0(b, c, d);
                            k_const = 32'h5a827999;
                        end else if (round_counter < 40) begin
                            f_result = f1(b, c, d);
                            k_const = 32'h6ed9eba1;
                        end else if (round_counter < 60) begin
                            f_result = f2(b, c, d);
                            k_const = 32'h8f1bbcdc;
                        end else begin
                            f_result = f1(b, c, d);
                            k_const = 32'hca62c1d6;
                        end
                        
                        // Compute temp = ROTL^5(a) + f + e + k + w[i]
                        temp = rotate_left(a, 5'd5) + f_result + e + k_const + w[round_counter];
                        
                        // Update working variables
                        e_next = d;
                        d_next = c;
                        c_next = rotate_left(b, 5'd30);
                        b_next = a;
                        a_next = temp;
                        
                        e <= e_next;
                        d <= d_next;
                        c <= c_next;
                        b <= b_next;
                        a <= a_next;
                        
                        round_counter <= round_counter + 1;
                    end else begin
                        // All rounds done
                        state <= 2'b11;
                    end
                end
                2'b11: begin  // Update hash state
                    h0 <= h0 + a;
                    h1 <= h1 + b;
                    h2 <= h2 + c;
                    h3 <= h3 + d;
                    h4 <= h4 + e;
                    hash_out <= {h4 + e, h3 + d, h2 + c, h1 + b, h0 + a};
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
