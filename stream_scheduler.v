// Multi-Stream Scheduler Module
// Distributes data streams to multiple pipelines
// Each pipeline processes one complete stream (multiple blocks)

module stream_scheduler #(
    parameter NUM_PIPELINES = 16
)(
    input wire         clk,
    input wire         rst_n,
    
    // Input from AXI interface
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    input wire         block_last,
    input wire [3:0]   stream_id,  // Stream ID from TID
    
    // Output to pipelines
    output reg [511:0] pipeline_block_data [0:NUM_PIPELINES-1],
    output reg         pipeline_block_valid [0:NUM_PIPELINES-1],
    input wire [NUM_PIPELINES-1:0] pipeline_block_ready,
    output reg [3:0]   pipeline_stream_id [0:NUM_PIPELINES-1],
    output reg         pipeline_block_last [0:NUM_PIPELINES-1],
    
    // Pipeline status
    input wire [NUM_PIPELINES-1:0] pipeline_busy,
    
    // Pipeline assignment
    output reg [3:0]   assigned_pipeline,
    output reg         assignment_valid
);

    // Stream to pipeline mapping
    reg [3:0] stream_to_pipeline [0:15];  // Map stream_id to pipeline
    reg       stream_active [0:15];        // Stream is being processed
    
    // Round-robin pointer for new streams
    reg [3:0] next_free_pipeline;
    
    // Find pipeline for stream
    reg [3:0] target_pipeline;
    reg       pipeline_found;
    integer i;
    
    always @(*) begin
        pipeline_found = 1'b0;
        target_pipeline = 4'b0;
        
        // Check if stream is already assigned to a pipeline
        for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
            if (pipeline_busy[i] && (pipeline_stream_id[i] == stream_id)) begin
                pipeline_found = 1'b1;
                target_pipeline = i[3:0];
            end
        end
        
        // If not found, find next free pipeline
        if (!pipeline_found) begin
            for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
                if (!pipeline_busy[i] && pipeline_block_ready[i]) begin
                    pipeline_found = 1'b1;
                    target_pipeline = i[3:0];
                    break;
                end
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i = i + 1) begin
                stream_to_pipeline[i] <= 4'b0;
                stream_active[i] <= 1'b0;
            end
            for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
                pipeline_block_data[i] <= 512'b0;
                pipeline_block_valid[i] <= 1'b0;
                pipeline_block_last[i] <= 1'b0;
                pipeline_stream_id[i] <= 4'b0;
            end
            next_free_pipeline <= 4'b0;
            assigned_pipeline <= 4'b0;
            assignment_valid <= 1'b0;
            block_ready <= 1'b0;
        end else begin
            assignment_valid <= 1'b0;
            
            if (block_valid && pipeline_found) begin
                // Assign block to pipeline
                pipeline_block_data[target_pipeline] <= block_data;
                pipeline_block_valid[target_pipeline] <= block_valid;
                pipeline_block_last[target_pipeline] <= block_last;
                pipeline_stream_id[target_pipeline] <= stream_id;
                assigned_pipeline <= target_pipeline;
                assignment_valid <= 1'b1;
                block_ready <= pipeline_block_ready[target_pipeline];
                
                // Update stream mapping if new stream
                if (!stream_active[stream_id]) begin
                    stream_to_pipeline[stream_id] <= target_pipeline;
                    stream_active[stream_id] <= 1'b1;
                end
                
                // Clear stream active flag on last block
                if (block_last) begin
                    stream_active[stream_id] <= 1'b0;
                end
            end else begin
                pipeline_block_valid[target_pipeline] <= 1'b0;
                block_ready <= 1'b0;
            end
            
            // Update next free pipeline (round-robin)
            if (!pipeline_busy[next_free_pipeline] && pipeline_block_ready[next_free_pipeline]) begin
                // Current pipeline is free, keep it
            end else begin
                // Find next free pipeline
                for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
                    if (!pipeline_busy[(next_free_pipeline + i + 1) % NUM_PIPELINES] && 
                        pipeline_block_ready[(next_free_pipeline + i + 1) % NUM_PIPELINES]) begin
                        next_free_pipeline <= (next_free_pipeline + i + 1) % NUM_PIPELINES;
                        break;
                    end
                end
            end
        end
    end

endmodule
