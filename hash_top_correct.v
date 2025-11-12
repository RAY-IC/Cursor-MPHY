// Correct Hash Top Module for Single Data Stream
// Uses deep pipeline for block-level pipelining

module hash_top_correct (
    input wire         clk,
    input wire         rst_n,
    
    // AXI-Stream Slave Interface (Input)
    input wire [255:0] s_axis_tdata,
    input wire         s_axis_tvalid,
    output reg         s_axis_tready,
    input wire         s_axis_tlast,
    input wire [31:0]  s_axis_tkeep,
    
    // AXI-Stream Master Interface (Output)
    output reg [255:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input wire         m_axis_tready,
    output reg         m_axis_tlast,
    
    // Control Interface
    input wire [1:0]   algorithm_sel,  // 00: MD5, 01: SHA256, 10: SHA1
    input wire         start,
    output reg         ready,
    output reg         done
);

    // Internal signals
    wire [511:0] axi_block_data;
    wire        axi_block_valid;
    reg         axi_block_ready;
    wire        axi_block_last;
    
    wire [511:0] formatted_block_data;
    wire        formatted_block_valid;
    reg         formatted_block_ready;
    
    // Hash core signals
    wire [127:0] md5_hash_out;
    wire        md5_hash_valid;
    reg         md5_hash_ready;
    
    wire [255:0] sha256_hash_out;
    wire        sha256_hash_valid;
    reg         sha256_hash_ready;
    
    wire [159:0] sha1_hash_out;
    wire        sha1_hash_valid;
    reg         sha1_hash_ready;
    
    // Hash result mux
    reg [255:0] hash_result;
    reg        hash_result_valid;
    wire       hash_result_ready;
    reg [1:0]  hash_size;
    
    // Message length counter
    reg [63:0] total_length;
    
    // Instantiate AXI Stream Interface
    axi_stream_if u_axi_if (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tkeep(s_axis_tkeep),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .block_data(axi_block_data),
        .block_valid(axi_block_valid),
        .block_ready(axi_block_ready),
        .block_last(axi_block_last),
        .hash_result(hash_result),
        .hash_valid(hash_result_valid),
        .hash_ready(hash_result_ready),
        .hash_size(hash_size),
        .algorithm_sel(algorithm_sel),
        .ready(ready)
    );
    
    // Instantiate Block Formatter
    block_formatter u_formatter (
        .clk(clk),
        .rst_n(rst_n),
        .block_in(axi_block_data),
        .block_valid(axi_block_valid),
        .block_ready(axi_block_ready),
        .block_last(axi_block_last),
        .block_out(formatted_block_data),
        .block_out_valid(formatted_block_valid),
        .block_out_ready(formatted_block_ready),
        .algorithm_sel(algorithm_sel),
        .total_length(total_length),
        .formatting_done()
    );
    
    // Algorithm router
    assign formatted_block_ready = (algorithm_sel == 2'b00) ? md5_hash_ready :
                                   (algorithm_sel == 2'b01) ? sha256_hash_ready :
                                   (algorithm_sel == 2'b10) ? sha1_hash_ready : 1'b0;
    
    // Instantiate MD5 Core (pipelined version)
    md5_core_pipelined u_md5 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(formatted_block_data),
        .block_valid(formatted_block_valid && (algorithm_sel == 2'b00)),
        .block_ready(md5_hash_ready),
        .block_last(axi_block_last),
        .hash_out(md5_hash_out),
        .hash_valid(md5_hash_valid),
        .hash_ready(md5_hash_ready),
        .start(start),
        .ready()
    );
    
    // TODO: Instantiate SHA256 and SHA1 pipelined cores
    // For now, use original cores (will be updated)
    sha256_core u_sha256 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(formatted_block_data),
        .block_valid(formatted_block_valid && (algorithm_sel == 2'b01)),
        .block_ready(sha256_hash_ready),
        .hash_out(sha256_hash_out),
        .hash_valid(sha256_hash_valid),
        .hash_ready(sha256_hash_ready),
        .start(start),
        .done()
    );
    
    sha1_core u_sha1 (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(formatted_block_data),
        .block_valid(formatted_block_valid && (algorithm_sel == 2'b10)),
        .block_ready(sha1_hash_ready),
        .hash_out(sha1_hash_out),
        .hash_valid(sha1_hash_valid),
        .hash_ready(sha1_hash_ready),
        .start(start),
        .done()
    );
    
    // Hash result mux
    always @(*) begin
        case (algorithm_sel)
            2'b00: begin  // MD5
                hash_result = {128'b0, md5_hash_out};
                hash_result_valid = md5_hash_valid;
                md5_hash_ready = hash_result_ready;
                sha256_hash_ready = 1'b0;
                sha1_hash_ready = 1'b0;
                hash_size = 2'b00;
            end
            2'b01: begin  // SHA256
                hash_result = sha256_hash_out;
                hash_result_valid = sha256_hash_valid;
                md5_hash_ready = 1'b0;
                sha256_hash_ready = hash_result_ready;
                sha1_hash_ready = 1'b0;
                hash_size = 2'b01;
            end
            2'b10: begin  // SHA1
                hash_result = {96'b0, sha1_hash_out};
                hash_result_valid = sha1_hash_valid;
                md5_hash_ready = 1'b0;
                sha256_hash_ready = 1'b0;
                sha1_hash_ready = hash_result_ready;
                hash_size = 2'b10;
            end
            default: begin
                hash_result = 256'b0;
                hash_result_valid = 1'b0;
                md5_hash_ready = 1'b0;
                sha256_hash_ready = 1'b0;
                sha1_hash_ready = 1'b0;
                hash_size = 2'b00;
            end
        endcase
    end
    
    assign hash_result_ready = 1'b1;
    
    // Message length counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            total_length <= 64'b0;
        end else begin
            if (start) begin
                total_length <= 64'b0;
            end else if (s_axis_tvalid && s_axis_tready) begin
                total_length <= total_length + 256;
                if (s_axis_tlast) begin
                    // Adjust for actual valid bytes
                end
            end
        end
    end
    
    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            case (algorithm_sel)
                2'b00: done <= md5_hash_valid && md5_hash_ready;
                2'b01: done <= sha256_hash_valid && sha256_hash_ready;
                2'b10: done <= sha1_hash_valid && sha1_hash_ready;
                default: done <= 1'b0;
            endcase
        end
    end

endmodule
