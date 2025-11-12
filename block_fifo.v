// Block FIFO Module
// Stores 512bit blocks for pipeline processing

module block_fifo #(
    parameter DEPTH = 16,  // FIFO depth
    parameter WIDTH = 512   // Block width
)(
    input wire         clk,
    input wire         rst_n,
    
    // Write interface
    input wire [WIDTH-1:0] wr_data,
    input wire         wr_en,
    output reg         full,
    
    // Read interface
    output reg [WIDTH-1:0] rd_data,
    input wire         rd_en,
    output reg         empty,
    
    // Status
    output reg [4:0]   count  // Current fill level
);

    // FIFO memory
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    
    // Read and write pointers
    reg [3:0] wr_ptr;
    reg [3:0] rd_ptr;
    
    // Internal signals
    wire [3:0] next_wr_ptr;
    wire [3:0] next_rd_ptr;
    wire fifo_full;
    wire fifo_empty;
    
    assign next_wr_ptr = (wr_ptr == (DEPTH-1)) ? 4'b0 : wr_ptr + 1;
    assign next_rd_ptr = (rd_ptr == (DEPTH-1)) ? 4'b0 : rd_ptr + 1;
    
    // Full/empty logic
    assign fifo_full = (count == DEPTH);
    assign fifo_empty = (count == 0);
    
    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 4'b0;
            for (integer i = 0; i < DEPTH; i = i + 1) begin
                mem[i] <= {WIDTH{1'b0}};
            end
        end else begin
            if (wr_en && !fifo_full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr <= next_wr_ptr;
            end
        end
    end
    
    // Read operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 4'b0;
            rd_data <= {WIDTH{1'b0}};
        end else begin
            if (rd_en && !fifo_empty) begin
                rd_data <= mem[rd_ptr];
                rd_ptr <= next_rd_ptr;
            end
        end
    end
    
    // Count logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 5'b0;
            full <= 1'b0;
            empty <= 1'b1;
        end else begin
            case ({wr_en && !fifo_full, rd_en && !fifo_empty})
                2'b10: count <= count + 1;  // Write only
                2'b01: count <= count - 1;  // Read only
                2'b11: count <= count;      // Both (no change)
                2'b00: count <= count;      // Neither
            endcase
            
            full <= fifo_full;
            empty <= fifo_empty;
        end
    end

endmodule
