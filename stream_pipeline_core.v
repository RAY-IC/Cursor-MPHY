// Stream Pipeline Core Module
// Processes one complete data stream (multiple blocks) with block-level pipelining

module stream_pipeline_core (
    input wire         clk,
    input wire         rst_n,
    
    // Block input
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    input wire         block_last,
    
    // Hash output (only valid when processing last block)
    output reg [255:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    
    // Control
    input wire [1:0]   algorithm_sel,  // 00: MD5, 01: SHA256, 10: SHA1
    input wire [3:0]   stream_id,      // Stream ID
    output reg [3:0]   output_stream_id,
    output reg         busy,
    output reg         ready
);

    // Use pipelined MD5 core for block-level pipelining
    wire [127:0] md5_hash;
    wire        md5_hash_valid;
    reg         md5_hash_ready;
    reg         md5_block_ready;
    
    // Use original SHA256/SHA1 cores (can be upgraded later)
    wire [255:0] sha256_hash;
    wire        sha256_hash_valid;
    reg         sha256_hash_ready;
    reg         sha256_block_ready;
    
    wire [159:0] sha1_hash;
    wire        sha1_hash_valid;
    reg         sha1_hash_ready;
    reg         sha1_block_ready;
    
    // Stream ID register
    reg [3:0] stream_id_reg;
    
    // Instantiate MD5 pipelined core
    md5_core_pipelined u_md5 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(block_data),
        .block_valid(block_valid && (algorithm_sel == 2'b00)),
        .block_ready(md5_block_ready),
        .block_last(block_last),
        .hash_out(md5_hash),
        .hash_valid(md5_hash_valid),
        .hash_ready(md5_hash_ready),
        .start(1'b0),
        .ready()
    );
    
    // Instantiate SHA256 core
    sha256_core u_sha256 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(block_data),
        .block_valid(block_valid && (algorithm_sel == 2'b01)),
        .block_ready(sha256_block_ready),
        .hash_out(sha256_hash),
        .hash_valid(sha256_hash_valid),
        .hash_ready(sha256_hash_ready),
        .start(1'b0),
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
        .hash_valid(sha1_hash_valid),
        .hash_ready(sha1_hash_ready),
        .start(1'b0),
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
                hash_valid = md5_hash_valid;
                md5_hash_ready = hash_ready;
                sha256_hash_ready = 1'b0;
                sha1_hash_ready = 1'b0;
            end
            2'b01: begin  // SHA256
                hash_out = sha256_hash;
                hash_valid = sha256_hash_valid;
                md5_hash_ready = 1'b0;
                sha256_hash_ready = hash_ready;
                sha1_hash_ready = 1'b0;
            end
            2'b10: begin  // SHA1
                hash_out = {96'b0, sha1_hash};
                hash_valid = sha1_hash_valid;
                md5_hash_ready = 1'b0;
                sha256_hash_ready = 1'b0;
                sha1_hash_ready = hash_ready;
            end
            default: begin
                hash_out = 256'b0;
                hash_valid = 1'b0;
                md5_hash_ready = 1'b0;
                sha256_hash_ready = 1'b0;
                sha1_hash_ready = 1'b0;
            end
        endcase
    end
    
    // Stream ID and busy logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stream_id_reg <= 4'b0;
            output_stream_id <= 4'b0;
            busy <= 1'b0;
            ready <= 1'b1;
        end else begin
            // Capture stream ID when first block arrives
            if (block_valid && block_ready && !busy) begin
                stream_id_reg <= stream_id;
                busy <= 1'b1;
            end
            
            // Output stream ID with hash result
            if (hash_valid) begin
                output_stream_id <= stream_id_reg;
            end
            
            // Clear busy when stream completes
            if (hash_valid && hash_ready && block_last) begin
                busy <= 1'b0;
            end
            
            ready <= 1'b1;
        end
    end

endmodule
