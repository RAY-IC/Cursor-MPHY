// Round-Robin Scheduler Module
// Distributes 512bit blocks to multiple pipelines

module scheduler #(
    parameter NUM_PIPELINES = 16
)(
    input wire         clk,
    input wire         rst_n,
    
    // Input from block formatter
    input wire [511:0] block_data,
    input wire         block_valid,
    output reg         block_ready,
    input wire         block_last,
    
    // Output to pipelines
    output reg [511:0] pipeline_block_data [0:NUM_PIPELINES-1],
    output reg         pipeline_block_valid [0:NUM_PIPELINES-1],
    input wire [NUM_PIPELINES-1:0] pipeline_block_ready,
    
    // Pipeline status
    input wire [NUM_PIPELINES-1:0] pipeline_busy,
    
    // Tag for ordering
    output reg [7:0]   block_tag,
    output reg         tag_valid
);

    // Round-robin pointer
    reg [3:0] current_pipeline;
    reg [7:0] tag_counter;
    
    // State machine
    reg [1:0] state;  // 0: idle, 1: selecting pipeline, 2: sending
    
    // Find next available pipeline
    reg [3:0] next_pipeline;
    integer i, j;
    always @(*) begin
        next_pipeline = current_pipeline;
        // Try current and next pipelines
        for (i = 0; i < NUM_PIPELINES; i = i + 1) begin
            j = (current_pipeline + i) % NUM_PIPELINES;
            if (!pipeline_busy[j] && pipeline_block_ready[j]) begin
                next_pipeline = j[3:0];
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pipeline <= 4'b0;
            tag_counter <= 8'b0;
            block_tag <= 8'b0;
            tag_valid <= 1'b0;
            state <= 2'b0;
            block_ready <= 1'b1;
        end else begin
            case (state)
                2'b00: begin  // Idle
                    if (block_valid) begin
                        // Use next available pipeline
                        current_pipeline <= next_pipeline;
                        tag_counter <= tag_counter + 1;
                        block_tag <= tag_counter;
                        tag_valid <= 1'b1;
                        state <= 2'b01;
                        block_ready <= 1'b0;
                    end else begin
                        tag_valid <= 1'b0;
                    end
                end
                2'b01: begin  // Selecting pipeline
                    // Wait for pipeline to be ready
                    if (pipeline_block_ready[current_pipeline] && !pipeline_busy[current_pipeline]) begin
                        // Send block to selected pipeline
                        pipeline_block_data[current_pipeline] <= block_data;
                        pipeline_block_valid[current_pipeline] <= 1'b1;
                        state <= 2'b10;
                    end
                end
                2'b10: begin  // Sending
                    if (pipeline_block_ready[current_pipeline]) begin
                        pipeline_block_valid[current_pipeline] <= 1'b0;
                        // Move to next pipeline for round-robin
                        if (current_pipeline == (NUM_PIPELINES - 1)) begin
                            current_pipeline <= 4'b0;
                        end else begin
                            current_pipeline <= current_pipeline + 1;
                        end
                        state <= 2'b00;
                        block_ready <= 1'b1;
                        tag_valid <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
