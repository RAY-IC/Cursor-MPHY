// Result Collector Module
// Collects hash results from multiple pipelines and maintains order

module result_collector #(
    parameter NUM_PIPELINES = 16,
    parameter QUEUE_DEPTH = 32
)(
    input wire         clk,
    input wire         rst_n,
    
    // Input from pipelines
    input wire [255:0] pipeline_hash [0:NUM_PIPELINES-1],
    input wire         pipeline_hash_valid [0:NUM_PIPELINES-1],
    output reg [NUM_PIPELINES-1:0] pipeline_hash_ready,
    input wire [7:0]   pipeline_hash_tag [0:NUM_PIPELINES-1],
    
    // Output to AXI interface
    output reg [255:0] hash_result,
    output reg         hash_valid,
    input wire         hash_ready,
    output reg [7:0]   hash_result_tag
);

    // Result queue
    reg [255:0] result_queue [0:QUEUE_DEPTH-1];
    reg [7:0]   tag_queue [0:QUEUE_DEPTH-1];
    reg         valid_queue [0:QUEUE_DEPTH-1];
    
    reg [4:0]   queue_head;
    reg [4:0]   queue_tail;
    reg [5:0]   queue_count;
    
    // Expected tag (for ordering)
    reg [7:0]   expected_tag;
    
    // Pipeline selection logic
    integer i;
    reg [3:0] selected_pipeline;
    reg found_result;
    
    // Find pipeline with matching tag
    always @(*) begin
        found_result = 1'b0;
        selected_pipeline = 4'b0;
        pipeline_hash_ready = {NUM_PIPELINES{1'b0}};
        
        // Check if queue has space
        if (queue_count < QUEUE_DEPTH) begin
            // Look for pipeline with expected tag
            for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
                if (!found_result && pipeline_hash_valid[i] && (pipeline_hash_tag[i] == expected_tag)) begin
                    found_result = 1'b1;
                    selected_pipeline = i[3:0];
                    pipeline_hash_ready[i] = 1'b1;
                end
            end
            
            // If not found, accept any valid result (for simplicity, can be optimized)
            if (!found_result) begin
                for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
                    if (!found_result && pipeline_hash_valid[i]) begin
                        found_result = 1'b1;
                        selected_pipeline = i[3:0];
                        pipeline_hash_ready[i] = 1'b1;
                    end
                end
            end
        end
    end
    
    // Queue management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            queue_head <= 5'b0;
            queue_tail <= 5'b0;
            queue_count <= 6'b0;
            expected_tag <= 8'b0;
            hash_valid <= 1'b0;
            for (integer j = 0; j < QUEUE_DEPTH; j = j + 1) begin
                valid_queue[j] <= 1'b0;
            end
        end else begin
            // Enqueue: accept result from pipeline
            if (found_result && pipeline_hash_ready[selected_pipeline]) begin
                result_queue[queue_tail] <= pipeline_hash[selected_pipeline];
                tag_queue[queue_tail] <= pipeline_hash_tag[selected_pipeline];
                valid_queue[queue_tail] <= 1'b1;
                queue_tail <= (queue_tail + 1) % QUEUE_DEPTH;
                queue_count <= queue_count + 1;
                
                // Update expected tag if this was the expected one
                if (pipeline_hash_tag[selected_pipeline] == expected_tag) begin
                    expected_tag <= expected_tag + 1;
                end
            end
            
            // Dequeue: output result
            if (hash_valid && hash_ready) begin
                valid_queue[queue_head] <= 1'b0;
                queue_head <= (queue_head + 1) % QUEUE_DEPTH;
                queue_count <= queue_count - 1;
                hash_valid <= 1'b0;
            end
            
            // Output next result from queue
            if (!hash_valid && valid_queue[queue_head]) begin
                hash_result <= result_queue[queue_head];
                hash_result_tag <= tag_queue[queue_head];
                hash_valid <= 1'b1;
            end
        end
    end

endmodule
