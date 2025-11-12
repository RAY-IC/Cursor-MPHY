// Shared Constants ROM Module
// Stores MD5/SHA256/SHA1 constants in BRAM
// Shared by all pipelines

module shared_constants_rom (
    input wire         clk,
    input wire         rst_n,
    
    // MD5 constants
    input wire [5:0]   md5_round_addr,
    output reg [31:0]  md5_k_const,
    output reg [4:0]   md5_s_const,
    
    // SHA256 constants
    input wire [5:0]   sha256_round_addr,
    output reg [31:0] sha256_k_const,
    
    // SHA1 constants
    input wire [6:0]   sha1_round_addr,
    output reg [31:0] sha1_k_const
);

    // MD5 K constants (64 values)
    reg [31:0] md5_k [0:63];
    reg [4:0]  md5_s [0:63];
    
    // SHA256 K constants (64 values)
    reg [31:0] sha256_k [0:63];
    
    // SHA1 K constants (80 values)
    reg [31:0] sha1_k [0:79];
    
    // Initialize constants
    initial begin
        // MD5 K constants
        md5_k[0] = 32'hd76aa478; md5_k[1] = 32'he8c7b756; md5_k[2] = 32'h242070db; md5_k[3] = 32'hc1bdceee;
        md5_k[4] = 32'hf57c0faf; md5_k[5] = 32'h4787c62a; md5_k[6] = 32'ha8304613; md5_k[7] = 32'hfd469501;
        md5_k[8] = 32'h698098d8; md5_k[9] = 32'h8b44f7af; md5_k[10] = 32'hffff5bb1; md5_k[11] = 32'h895cd7be;
        md5_k[12] = 32'h6b901122; md5_k[13] = 32'hfd987193; md5_k[14] = 32'ha679438e; md5_k[15] = 32'h49b40821;
        md5_k[16] = 32'hf61e2562; md5_k[17] = 32'hc040b340; md5_k[18] = 32'h265e5a51; md5_k[19] = 32'he9b6c7aa;
        md5_k[20] = 32'hd62f105d; md5_k[21] = 32'h02441453; md5_k[22] = 32'hd8a1e681; md5_k[23] = 32'he7d3fbc8;
        md5_k[24] = 32'h21e1cde6; md5_k[25] = 32'hc33707d6; md5_k[26] = 32'hf4d50d87; md5_k[27] = 32'h455a14ed;
        md5_k[28] = 32'ha9e3e905; md5_k[29] = 32'hfcefa3f8; md5_k[30] = 32'h676f02d9; md5_k[31] = 32'h8d2a4c8a;
        md5_k[32] = 32'hfffa3942; md5_k[33] = 32'h8771f681; md5_k[34] = 32'h6d9d6122; md5_k[35] = 32'hfde5380c;
        md5_k[36] = 32'ha4beea44; md5_k[37] = 32'h4bdecfa9; md5_k[38] = 32'hf6bb4b60; md5_k[39] = 32'hbebfbc70;
        md5_k[40] = 32'h289b7ec6; md5_k[41] = 32'heaa127fa; md5_k[42] = 32'hd4ef3085; md5_k[43] = 32'h04881d05;
        md5_k[44] = 32'hd9d4d039; md5_k[45] = 32'he6db99e5; md5_k[46] = 32'h1fa27cf8; md5_k[47] = 32'hc4ac5665;
        md5_k[48] = 32'hf4292244; md5_k[49] = 32'h432aff97; md5_k[50] = 32'hab9423a7; md5_k[51] = 32'hfc93a039;
        md5_k[52] = 32'hd655b1c3; md5_k[53] = 32'h8f0ccc92; md5_k[54] = 32'hffeff47d; md5_k[55] = 32'h85845dd1;
        md5_k[56] = 32'h6fa87e4f; md5_k[57] = 32'hfe2ce6e0; md5_k[58] = 32'ha3014314; md5_k[59] = 32'h4e0811a1;
        md5_k[60] = 32'hf7537e82; md5_k[61] = 32'hbd3af235; md5_k[62] = 32'h2ad7d2bb; md5_k[63] = 32'heb86d391;
        
        // MD5 S constants
        md5_s[0] = 5'd7; md5_s[1] = 5'd12; md5_s[2] = 5'd17; md5_s[3] = 5'd22;
        md5_s[4] = 5'd7; md5_s[5] = 5'd12; md5_s[6] = 5'd17; md5_s[7] = 5'd22;
        md5_s[8] = 5'd7; md5_s[9] = 5'd12; md5_s[10] = 5'd17; md5_s[11] = 5'd22;
        md5_s[12] = 5'd7; md5_s[13] = 5'd12; md5_s[14] = 5'd17; md5_s[15] = 5'd22;
        md5_s[16] = 5'd5; md5_s[17] = 5'd9; md5_s[18] = 5'd14; md5_s[19] = 5'd20;
        md5_s[20] = 5'd5; md5_s[21] = 5'd9; md5_s[22] = 5'd14; md5_s[23] = 5'd20;
        md5_s[24] = 5'd5; md5_s[25] = 5'd9; md5_s[26] = 5'd14; md5_s[27] = 5'd20;
        md5_s[28] = 5'd5; md5_s[29] = 5'd9; md5_s[30] = 5'd14; md5_s[31] = 5'd20;
        md5_s[32] = 5'd4; md5_s[33] = 5'd11; md5_s[34] = 5'd16; md5_s[35] = 5'd23;
        md5_s[36] = 5'd4; md5_s[37] = 5'd11; md5_s[38] = 5'd16; md5_s[39] = 5'd23;
        md5_s[40] = 5'd4; md5_s[41] = 5'd11; md5_s[42] = 5'd16; md5_s[43] = 5'd23;
        md5_s[44] = 5'd4; md5_s[45] = 5'd11; md5_s[46] = 5'd16; md5_s[47] = 5'd23;
        md5_s[48] = 5'd6; md5_s[49] = 5'd10; md5_s[50] = 5'd15; md5_s[51] = 5'd21;
        md5_s[52] = 5'd6; md5_s[53] = 5'd10; md5_s[54] = 5'd15; md5_s[55] = 5'd21;
        md5_s[56] = 5'd6; md5_s[57] = 5'd10; md5_s[58] = 5'd15; md5_s[59] = 5'd21;
        md5_s[60] = 5'd6; md5_s[61] = 5'd10; md5_s[62] = 5'd15; md5_s[63] = 5'd21;
        
        // SHA256 K constants (simplified, full list in actual implementation)
        sha256_k[0] = 32'h428a2f98; sha256_k[1] = 32'h71374491; sha256_k[2] = 32'hb5c0fbcf; sha256_k[3] = 32'he9b5dba5;
        // ... (full 64 values)
        
        // SHA1 K constants (simplified, full list in actual implementation)
        sha1_k[0] = 32'h5a827999; sha1_k[1] = 32'h5a827999; // ... (full 80 values)
    end
    
    // Read MD5 constants
    always @(posedge clk) begin
        if (!rst_n) begin
            md5_k_const <= 32'b0;
            md5_s_const <= 5'b0;
        end else begin
            md5_k_const <= md5_k[md5_round_addr];
            md5_s_const <= md5_s[md5_round_addr];
        end
    end
    
    // Read SHA256 constants
    always @(posedge clk) begin
        if (!rst_n) begin
            sha256_k_const <= 32'b0;
        end else begin
            sha256_k_const <= sha256_k[sha256_round_addr];
        end
    end
    
    // Read SHA1 constants
    always @(posedge clk) begin
        if (!rst_n) begin
            sha1_k_const <= 32'b0;
        end else begin
            sha1_k_const <= sha1_k[sha1_round_addr];
        end
    end

endmodule
