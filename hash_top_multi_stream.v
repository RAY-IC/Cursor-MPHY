// Multi-Stream Hash Top Module
// Supports 16 parallel pipelines for 15GB/s throughput

module hash_top_multi_stream #(
    parameter NUM_PIPELINES = 16
)(
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
    wire [3:0]  axi_block_stream_id;
    
    wire [511:0] formatted_block_data;
    wire        formatted_block_valid;
    reg         formatted_block_ready;
    wire        formatted_block_last;
    
    // Pipeline signals
    wire [511:0] pipeline_block_data [0:NUM_PIPELINES-1];
    wire [NUM_PIPELINES-1:0] pipeline_block_valid;
    wire [NUM_PIPELINES-1:0] pipeline_block_ready;
    wire [NUM_PIPELINES-1:0] pipeline_block_last;
    wire [NUM_PIPELINES-1:0] pipeline_busy;
    wire [3:0]   pipeline_stream_id [0:NUM_PIPELINES-1];
    wire [3:0]   pipeline_output_stream_id [0:NUM_PIPELINES-1];
    
    // Hash output signals
    wire [255:0] pipeline_hash [0:NUM_PIPELINES-1];
    wire [NUM_PIPELINES-1:0] pipeline_hash_valid;
    reg [NUM_PIPELINES-1:0] pipeline_hash_ready;
    
    // Collector output
    wire [255:0] collector_hash;
    wire        collector_hash_valid;
    reg         collector_hash_ready;
    wire [3:0]  collector_stream_id;
    
    // Scheduler signals
    wire [3:0]  assigned_pipeline;
    wire        assignment_valid;
    
    // Instantiate AXI Stream Interface
    axi_stream_if_multi u_axi_if (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tid(s_axis_tid),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tid(m_axis_tid),
        .block_data(axi_block_data),
        .block_valid(axi_block_valid),
        .block_ready(axi_block_ready),
        .block_last(axi_block_last),
        .block_stream_id(axi_block_stream_id),
        .hash_result(collector_hash),
        .hash_valid(collector_hash_valid),
        .hash_ready(collector_hash_ready),
        .hash_stream_id(collector_stream_id),
        .hash_size(algorithm_sel),
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
        .total_length(64'b0),
        .formatting_done()
    );
    
    assign formatted_block_last = axi_block_last;
    
    // Instantiate Stream Scheduler
    stream_scheduler #(
        .NUM_PIPELINES(NUM_PIPELINES)
    ) u_scheduler (
        .clk(clk),
        .rst_n(rst_n),
        .block_data(formatted_block_data),
        .block_valid(formatted_block_valid),
        .block_ready(formatted_block_ready),
        .block_last(formatted_block_last),
        .stream_id(axi_block_stream_id),
        .pipeline_block_data(pipeline_block_data),
        .pipeline_block_valid(pipeline_block_valid),
        .pipeline_block_ready(pipeline_block_ready),
        .pipeline_block_last(pipeline_block_last),
        .pipeline_stream_id(pipeline_stream_id),
        .pipeline_busy(pipeline_busy),
        .assigned_pipeline(assigned_pipeline),
        .assignment_valid(assignment_valid)
    );
    
    // Instantiate 16 Pipeline Cores
    genvar i;
    generate
        for (i = 0; i < NUM_PIPELINES; i = i + 1) begin : pipeline_gen
            stream_pipeline_core u_pipeline (
                .clk(clk),
                .rst_n(rst_n),
                .block_data(pipeline_block_data[i]),
                .block_valid(pipeline_block_valid[i]),
                .block_ready(pipeline_block_ready[i]),
                .block_last(pipeline_block_last[i]),
                .hash_out(pipeline_hash[i]),
                .hash_valid(pipeline_hash_valid[i]),
                .hash_ready(pipeline_hash_ready[i]),
                .algorithm_sel(algorithm_sel),
                .stream_id(pipeline_stream_id[i]),
                .output_stream_id(pipeline_output_stream_id[i]),
                .busy(pipeline_busy[i]),
                .ready()
            );
        end
    endgenerate
    
    // Instantiate Result Collector
    result_collector_multi_stream #(
        .NUM_PIPELINES(NUM_PIPELINES)
    ) u_collector (
        .clk(clk),
        .rst_n(rst_n),
        .pipeline_hash(pipeline_hash),
        .pipeline_hash_valid(pipeline_hash_valid),
        .pipeline_hash_ready(pipeline_hash_ready),
        .pipeline_stream_id(pipeline_output_stream_id),
        .hash_out(collector_hash),
        .hash_valid(collector_hash_valid),
        .hash_ready(collector_hash_ready),
        .output_stream_id(collector_stream_id)
    );
    
    assign collector_hash_ready = 1'b1;
    
    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            done <= collector_hash_valid && collector_hash_ready;
        end
    end

endmodule
