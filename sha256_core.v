// SHA256 Hash Core Module
// Implements SHA256 algorithm with pipeline optimization

module sha256_core (
    input wire         clk,
    input wire         rst_n,
    
    // Block input
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    
    // Hash output
    output reg [255:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    
    // Control
    input wire         start,
    output reg         done
);

    // SHA256 constants
    parameter [31:0] K [0:63] = '{
        32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5,
        32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
        32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3,
        32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
        32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc,
        32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
        32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7,
        32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
        32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13,
        32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
        32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3,
        32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
        32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5,
        32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
        32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208,
        32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
    };
    
    // SHA256 state registers
    reg [31:0] h0, h1, h2, h3, h4, h5, h6, h7;
    reg [31:0] a, b, c, d, e, f, g, h;
    reg [31:0] a_next, b_next, c_next, d_next, e_next, f_next, g_next, h_next;
    reg [31:0] T1, T2;  // Temporary variables for round computation
    
    // Message schedule W[0..63]
    reg [31:0] w [0:63];
    
    // Pipeline registers
    reg [511:0] block_reg;
    reg [5:0]   round_counter;
    reg [1:0]   state;  // 0: idle, 1: message expansion, 2: main loop, 3: update
    
    // SHA256 functions
    function [31:0] Ch;
        input [31:0] x, y, z;
        Ch = (x & y) ^ (~x & z);
    endfunction
    
    function [31:0] Maj;
        input [31:0] x, y, z;
        Maj = (x & y) ^ (x & z) ^ (y & z);
    endfunction
    
    function [31:0] Sigma0;
        input [31:0] x;
        Sigma0 = {x[1:0], x[31:2]} ^ {x[12:0], x[31:13]} ^ {x[21:0], x[31:22]};
    endfunction
    
    function [31:0] Sigma1;
        input [31:0] x;
        Sigma1 = {x[5:0], x[31:6]} ^ {x[10:0], x[31:11]} ^ {x[24:0], x[31:25]};
    endfunction
    
    function [31:0] sigma0;
        input [31:0] x;
        sigma0 = {x[6:0], x[31:7]} ^ {x[17:0], x[31:18]} ^ (x >> 3);
    endfunction
    
    function [31:0] sigma1;
        input [31:0] x;
        sigma1 = {x[16:0], x[31:17]} ^ {x[18:0], x[31:19]} ^ (x >> 10);
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
            h0 <= 32'h6a09e667;
            h1 <= 32'hbb67ae85;
            h2 <= 32'h3c6ef372;
            h3 <= 32'ha54ff53a;
            h4 <= 32'h510e527f;
            h5 <= 32'h9b05688c;
            h6 <= 32'h1f83d9ab;
            h7 <= 32'h5be0cd19;
            a <= 32'h6a09e667;
            b <= 32'hbb67ae85;
            c <= 32'h3c6ef372;
            d <= 32'ha54ff53a;
            e <= 32'h510e527f;
            f <= 32'h9b05688c;
            g <= 32'h1f83d9ab;
            h <= 32'h5be0cd19;
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
                        e <= h4;
                        f <= h5;
                        g <= h6;
                        h <= h7;
                        round_counter <= 6'b0;
                        state <= 2'b01;  // Start message expansion
                        block_ready <= 1'b0;
                    end
                end
                2'b01: begin  // Message expansion: compute W[16..63]
                    if (round_counter < 16) begin
                        // W[0..15] already set from block
                        round_counter <= round_counter + 1;
                    end else if (round_counter < 48) begin
                        // Compute W[i] = sigma1(W[i-2]) + W[i-7] + sigma0(W[i-15]) + W[i-16]
                        w[round_counter] <= sigma1(w[round_counter-2]) + w[round_counter-7] + 
                                           sigma0(w[round_counter-15]) + w[round_counter-16];
                        round_counter <= round_counter + 1;
                    end else begin
                        // Message expansion done, start main loop
                        round_counter <= 6'b0;
                        state <= 2'b10;
                    end
                end
                2'b10: begin  // Main loop: 64 rounds
                    if (round_counter < 64) begin
                        // Compute T1 and T2
                        T1 = h + Sigma1(e) + Ch(e, f, g) + K[round_counter] + w[round_counter];
                        T2 = Sigma0(a) + Maj(a, b, c);
                        
                        // Update working variables
                        h_next = g;
                        g_next = f;
                        f_next = e;
                        e_next = d + T1;
                        d_next = c;
                        c_next = b;
                        b_next = a;
                        a_next = T1 + T2;
                        
                        h <= h_next;
                        g <= g_next;
                        f <= f_next;
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
                    h5 <= h5 + f;
                    h6 <= h6 + g;
                    h7 <= h7 + h;
                    hash_out <= {h7 + h, h6 + g, h5 + f, h4 + e, 
                                h3 + d, h2 + c, h1 + b, h0 + a};
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
