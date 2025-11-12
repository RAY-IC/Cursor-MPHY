// AXI-Stream Interface Module
// Handles 256bit AXI-Stream input/output

module axi_stream_if (
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
    
    // Internal Interface to Hash Core
    output reg [511:0] block_data,
    output reg         block_valid,
    input wire         block_ready,
    output reg         block_last,
    
    // Hash result from core
    input wire [255:0] hash_result,
    input wire         hash_valid,
    output reg         hash_ready,
    input wire [1:0]   hash_size,  // 00: 128bit(MD5), 01: 256bit(SHA256), 10: 160bit(SHA1)
    
    // Internal ready signal
    wire hash_result_ready_internal;
    
    // Control
    input wire [1:0]   algorithm_sel,
    output reg         ready
);

    // Input buffer state machine
    reg [255:0] input_buffer;
    reg         buffer_half_full;
    reg [511:0] full_block;
    
    // Output buffer
    reg [255:0] output_buffer;
    reg         output_valid_reg;
    reg [1:0]   output_state;  // 0: idle, 1: first half, 2: second half
    
    // Input state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            input_buffer <= 256'b0;
            buffer_half_full <= 1'b0;
            full_block <= 512'b0;
            block_valid <= 1'b0;
            block_last <= 1'b0;
            s_axis_tready <= 1'b1;
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                if (!buffer_half_full) begin
                    // First half of block
                    input_buffer <= s_axis_tdata;
                    buffer_half_full <= 1'b1;
                    block_last <= s_axis_tlast;
                end else begin
                    // Second half of block - form complete 512bit block
                    full_block <= {s_axis_tdata, input_buffer};
                    buffer_half_full <= 1'b0;
                    block_valid <= 1'b1;
                    block_last <= s_axis_tlast;
                end
            end
            
            if (block_valid && block_ready) begin
                block_valid <= 1'b0;
            end
            
            // Handle last packet with odd number of 256bit words
            if (s_axis_tlast && s_axis_tvalid && s_axis_tready && !buffer_half_full) begin
                // Last packet is first half only - pad with zeros
                full_block <= {256'b0, s_axis_tdata};
                buffer_half_full <= 1'b0;
                block_valid <= 1'b1;
                block_last <= 1'b1;
            end
        end
    end
    
    assign block_data = full_block;
    
    assign hash_result_ready_internal = (output_state == 2'b00) && !m_axis_tvalid;
    assign hash_ready = hash_result_ready_internal;
    
    // Output state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tdata <= 256'b0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            output_buffer <= 256'b0;
            output_state <= 2'b0;
        end else begin
            case (output_state)
                2'b00: begin  // Idle
                    if (hash_valid && hash_result_ready_internal) begin
                        case (hash_size)
                            2'b00: begin  // MD5: 128bit
                                m_axis_tdata <= {128'b0, hash_result[127:0]};
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast <= 1'b1;
                            end
                            2'b01: begin  // SHA256: 256bit
                                m_axis_tdata <= hash_result;
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast <= 1'b1;
                            end
                            2'b10: begin  // SHA1: 160bit
                                m_axis_tdata <= {96'b0, hash_result[159:0]};
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast <= 1'b1;
                            end
                            default: begin
                                m_axis_tdata <= hash_result;
                                m_axis_tvalid <= 1'b1;
                                m_axis_tlast <= 1'b1;
                            end
                        endcase
                    end
                end
                2'b01, 2'b10: begin
                    // Should not reach here with current design
                    output_state <= 2'b00;
                end
            endcase
            
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast <= 1'b0;
            end
        end
    end
    
    // Ready signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b0;
        end else begin
            ready <= 1'b1;  // Always ready when not reset
        end
    end

endmodule
