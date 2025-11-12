// Multi-Stream Result Collector Module
// Collects hash results from multiple pipelines and outputs in order

module result_collector_multi_stream #(
    parameter NUM_PIPELINES = 16
)(
    input wire         clk,
    input wire         rst_n,
    
    // Input from pipelines
    input wire [255:0] pipeline_hash [0:NUM_PIPELINES-1],
    input wire [NUM_PIPELINES-1:0] pipeline_hash_valid,
    output reg [NUM_PIPELINES-1:0] pipeline_hash_ready,
    input wire [NUM_PIPELINES-1:0] pipeline_stream_id [0:NUM_PIPELINES-1],
    
    // Output
    output reg [255:0] hash_out,
    output reg         hash_valid,
    input wire         hash_ready,
    output reg [3:0]  output_stream_id
);

    // Result FIFO for each stream (simplified: use round-robin output)
    // In practice, could use proper FIFO for each stream
    
    // Round-robin output
    reg [3:0] output_pointer;
    reg       found_result;
    integer i;
    
    always @(*) begin
        found_result = 1'b0;
        hash_valid = 1'b0;
        hash_out = 256'b0;
        output_stream_id = 4'b0;
        
        // Check pipelines in round-robin order
        for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
            if (!found_result && pipeline_hash_valid[(output_pointer + i) % NUM_PIPELINES]) begin
                found_result = 1'b1;
                hash_valid = 1'b1;
                hash_out = pipeline_hash[(output_pointer + i) % NUM_PIPELINES];
                output_stream_id = pipeline_stream_id[(output_pointer + i) % NUM_PIPELINES];
            end
        end
        
        // Set ready signals
        for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
            if (found_result && ((output_pointer + i) % NUM_PIPELINES == i)) begin
                pipeline_hash_ready[i] = hash_ready;
            end else begin
                pipeline_hash_ready[i] = 1'b0;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_pointer <= 4'b0;
        end else begin
            if (hash_valid && hash_ready) begin
                // Move to next pipeline
                output_pointer <= (output_pointer + 1) % NUM_PIPELINES;
            end
        end
    end

endmodule
