// AXI-Stream Interface Module for Multi-Stream
// Handles 256bit AXI-Stream input/output with TID support

module axi_stream_if_multi (
    input wire         clk,
    input wire         rst_n,
    
    // AXI-Stream Slave Interface (Input)
    input wire [255:0] s_axis_tdata,
    input wire         s_axis_tvalid,
    output reg         s_axis_tready,
    input wire         s_axis_tlast,
    input wire [31:0]  s_axis_tkeep,
    input wire [3:0]   s_axis_tid,  // Stream ID
    
    // AXI-Stream Master Interface (Output)
    output reg [255:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input wire         m_axis_tready,
    output reg         m_axis_tlast,
    output reg [3:0]   m_axis_tid,  // Stream ID
    
    // Internal Interface to Block Formatter
    output reg [511:0] block_data,
    output reg         block_valid,
    input wire         block_ready,
    output reg         block_last,
    output reg [3:0]   block_stream_id,
    
    // Hash result from collector
    input wire [255:0] hash_result,
    input wire         hash_valid,
    output reg         hash_ready,
    input wire [3:0]   hash_stream_id,
    input wire [1:0]   hash_size,  // 00: 128bit(MD5), 01: 256bit(SHA256), 10: 160bit(SHA1)
    
    // Control
    input wire [1:0]   algorithm_sel,
    output reg         ready
);

    // Input buffer state machine
    reg [255:0] input_buffer;
    reg         buffer_half_full;
    reg [511:0] full_block;
    reg [3:0]   current_stream_id;
    
    // Output buffer
    reg [255:0] output_buffer;
    reg         output_valid_reg;
    reg [1:0]   output_state;  // 0: idle, 1: first half, 2: second half
    reg [3:0]   output_stream_id;
    
    // Input: Convert 256bit AXI to 512bit blocks
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_buffer <= 256'b0;
            buffer_half_full <= 1'b0;
            full_block <= 512'b0;
            block_data <= 512'b0;
            block_valid <= 1'b0;
            block_last <= 1'b0;
            block_stream_id <= 4'b0;
            current_stream_id <= 4'b0;
            s_axis_tready <= 1'b1;
            ready <= 1'b0;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                current_stream_id <= s_axis_tid;
                
                if (!buffer_half_full) begin
                    // First half of block
                    input_buffer <= s_axis_tdata;
                    buffer_half_full <= 1'b1;
                    s_axis_tready <= 1'b1;
                end else begin
                    // Second half of block - form complete block
                    full_block <= {s_axis_tdata, input_buffer};
                    block_data <= {s_axis_tdata, input_buffer};
                    block_valid <= 1'b1;
                    block_last <= s_axis_tlast;
                    block_stream_id <= current_stream_id;
                    buffer_half_full <= 1'b0;
                    
                    if (block_ready) begin
                        block_valid <= 1'b0;
                        s_axis_tready <= 1'b1;
                    end else begin
                        s_axis_tready <= 1'b0;
                    end
                end
                
                // Handle last packet when buffer is half full
                if (s_axis_tlast && !buffer_half_full) begin
                    // Last packet and buffer empty - pad to 512bit
                    full_block <= {256'b0, s_axis_tdata};
                    block_data <= {256'b0, s_axis_tdata};
                    block_valid <= 1'b1;
                    block_last <= 1'b1;
                    block_stream_id <= s_axis_tid;
                    buffer_half_full <= 1'b0;
                    
                    if (block_ready) begin
                        block_valid <= 1'b0;
                        s_axis_tready <= 1'b1;
                    end else begin
                        s_axis_tready <= 1'b0;
                    end
                end
            end else begin
                if (block_valid && block_ready) begin
                    block_valid <= 1'b0;
                    s_axis_tready <= 1'b1;
                end
            end
            
            ready <= 1'b1;
        end
    end
    
    // Output: Convert hash result to 256bit AXI
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_buffer <= 256'b0;
            output_valid_reg <= 1'b0;
            output_state <= 2'b0;
            m_axis_tdata <= 256'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tid <= 4'b0;
            hash_ready <= 1'b0;
            output_stream_id <= 4'b0;
        end else begin
            case (output_state)
                2'b00: begin  // Idle
                    if (hash_valid) begin
                        output_stream_id <= hash_stream_id;
                        case (hash_size)
                            2'b00: begin  // MD5: 128bit
                                m_axis_tdata <= {128'b0, hash_result[127:0]};
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast <= 1'b1;
                                m_axis_tid <= hash_stream_id;
                                output_state <= 2'b00;
                                hash_ready <= 1'b1;
                            end
                            2'b01: begin  // SHA256: 256bit
                                m_axis_tdata <= hash_result[255:0];
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast <= 1'b1;
                                m_axis_tid <= hash_stream_id;
                                output_state <= 2'b00;
                                hash_ready <= 1'b1;
                            end
                            2'b10: begin  // SHA1: 160bit
                                m_axis_tdata <= {96'b0, hash_result[159:0]};
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast <= 1'b1;
                                m_axis_tid <= hash_stream_id;
                                output_state <= 2'b00;
                                hash_ready <= 1'b1;
                            end
                            default: begin
                                hash_ready <= 1'b0;
                            end
                        endcase
                    end else begin
                        hash_ready <= 1'b0;
                    end
                end
            endcase
            
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast <= 1'b0;
                hash_ready <= 1'b0;
            end
        end
    end

endmodule
