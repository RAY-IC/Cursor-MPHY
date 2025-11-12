// Single Pipeline Core Module
// Supports MD5, SHA256, and SHA1 algorithms

module pipeline_core (
    input wire         clk,
    input wire         rst_n,
    
    // Block input
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    input wire [7:0]   block_tag,
    
    // Hash output
    output reg [255:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    output reg [7:0]   hash_tag,
    
    // Control
    input wire [1:0]   algorithm_sel,  // 00: MD5, 01: SHA256, 10: SHA1
    input wire         start,
    output reg         busy,
    output reg         done
);

    // Internal signals for MD5
    wire [127:0] md5_hash;
    wire        md5_valid;
    
    // Internal signals for SHA256
    wire [255:0] sha256_hash;
    wire        sha256_valid;
    
    // Internal signals for SHA1
    wire [159:0] sha1_hash;
    wire        sha1_valid;
    
    // Tag register
    reg [7:0] tag_reg;
    
    // Internal ready signals
    wire md5_block_ready, md5_hash_ready;
    wire sha256_block_ready, sha256_hash_ready;
    wire sha1_block_ready, sha1_hash_ready;
    
    // Instantiate MD5 core
    md5_core u_md5 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(block_data),
        .block_valid(block_valid && (algorithm_sel == 2'b00)),
        .block_ready(md5_block_ready),
        .hash_out(md5_hash),
        .hash_valid(md5_valid),
        .hash_ready(md5_hash_ready),
        .start(start),
        .done()
    );
    
    // Instantiate SHA256 core
    sha256_core u_sha256 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(block_data),
        .block_valid(block_valid && (algorithm_sel == 2'b01)),
        .block_ready(sha256_block_ready),
        .hash_out(sha256_hash),
        .hash_valid(sha256_valid),
        .hash_ready(sha256_hash_ready),
        .start(start),
        .done()
    );
    
    // Instantiate SHA1 core
    sha1_core u_sha1 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(block_data),
        .block_valid(block_valid && (algorithm_sel == 2'b10)),
        .block_ready(sha1_block_ready),
        .hash_out(sha1_hash),
        .hash_valid(sha1_valid),
        .hash_ready(sha1_hash_ready),
        .start(start),
        .done()
    );
    
    // Block ready logic
    always @(*) begin
        case (algorithm_sel)
            2'b00: block_ready = md5_block_ready;
            2'b01: block_ready = sha256_block_ready;
            2'b10: block_ready = sha1_block_ready;
            default: block_ready = 1'b0;
        endcase
    end
    
    // Hash output mux
    always @(*) begin
        case (algorithm_sel)
            2'b00: begin  // MD5
                hash_out = {128'b0, md5_hash};
                hash_valid = md5_valid;
            end
            2'b01: begin  // SHA256
                hash_out = sha256_hash;
                hash_valid = sha256_valid;
            end
            2'b10: begin  // SHA1
                hash_out = {96'b0, sha1_hash};
                hash_valid = sha1_valid;
            end
            default: begin
                hash_out = 256'b0;
                hash_valid = 1'b0;
            end
        endcase
    end
    
    // Assign ready signals based on algorithm selection
    assign md5_hash_ready = (algorithm_sel == 2'b00) ? hash_ready : 1'b0;
    assign sha256_hash_ready = (algorithm_sel == 2'b01) ? hash_ready : 1'b0;
    assign sha1_hash_ready = (algorithm_sel == 2'b10) ? hash_ready : 1'b0;
    
    // Tag and busy logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tag_reg <= 8'b0;
            hash_tag <= 8'b0;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            if (block_valid && block_ready) begin
                tag_reg <= block_tag;
                busy <= 1'b1;
            end
            
            if (hash_valid && hash_ready) begin
                hash_tag <= tag_reg;
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule
