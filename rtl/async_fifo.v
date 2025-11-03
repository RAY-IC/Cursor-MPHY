//=============================================================================
// Asynchronous FIFO
//=============================================================================
// Description: Generic async FIFO for cross-clock domain data transfer
//=============================================================================

module async_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH = 16,
    parameter ADDR_WIDTH = $clog2(DEPTH)
) (
    // Write side (source clock domain)
    input  wire                     wr_clk,
    input  wire                     wr_rstn,
    input  wire [DATA_WIDTH-1:0]   wr_data,
    input  wire                     wr_en,
    output reg                      wr_full,
    
    // Read side (destination clock domain)
    input  wire                     rd_clk,
    input  wire                     rd_rstn,
    input  wire                     rd_en,
    output reg  [DATA_WIDTH-1:0]   rd_data,
    output reg                      rd_empty
);

//=============================================================================
// Memory Array
//=============================================================================
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

//=============================================================================
// Write Pointer (Gray Code)
//=============================================================================
reg [ADDR_WIDTH:0] wr_ptr_bin;
reg [ADDR_WIDTH:0] wr_ptr_gray;
reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;

always @(posedge wr_clk or negedge wr_rstn) begin
    if (!wr_rstn) begin
        wr_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        wr_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
    end else if (wr_en && !wr_full) begin
        wr_ptr_bin <= wr_ptr_bin + 1'b1;
        wr_ptr_gray <= (wr_ptr_bin + 1'b1) ^ ((wr_ptr_bin + 1'b1) >> 1);
    end
end

//=============================================================================
// Read Pointer (Gray Code)
//=============================================================================
reg [ADDR_WIDTH:0] rd_ptr_bin;
reg [ADDR_WIDTH:0] rd_ptr_gray;
reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

always @(posedge rd_clk or negedge rd_rstn) begin
    if (!rd_rstn) begin
        rd_ptr_bin <= {(ADDR_WIDTH+1){1'b0}};
        rd_ptr_gray <= {(ADDR_WIDTH+1){1'b0}};
    end else if (rd_en && !rd_empty) begin
        rd_ptr_bin <= rd_ptr_bin + 1'b1;
        rd_ptr_gray <= (rd_ptr_bin + 1'b1) ^ ((rd_ptr_bin + 1'b1) >> 1);
    end
end

//=============================================================================
// Cross Clock Domain Synchronization
//=============================================================================
// Sync write pointer to read clock domain
always @(posedge rd_clk or negedge rd_rstn) begin
    if (!rd_rstn) begin
        wr_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
        wr_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
    end else begin
        wr_ptr_gray_sync1 <= wr_ptr_gray;
        wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
    end
end

// Sync read pointer to write clock domain
always @(posedge wr_clk or negedge wr_rstn) begin
    if (!wr_rstn) begin
        rd_ptr_gray_sync1 <= {(ADDR_WIDTH+1){1'b0}};
        rd_ptr_gray_sync2 <= {(ADDR_WIDTH+1){1'b0}};
    end else begin
        rd_ptr_gray_sync1 <= rd_ptr_gray;
        rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
    end
end

//=============================================================================
// Gray to Binary Conversion (for full/empty calculation)
//=============================================================================
function [ADDR_WIDTH:0] gray2bin;
    input [ADDR_WIDTH:0] gray;
    integer i;
    begin
        gray2bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
        for (i = ADDR_WIDTH-1; i >= 0; i = i - 1) begin
            gray2bin[i] = gray2bin[i+1] ^ gray[i];
        end
    end
endfunction

//=============================================================================
// Full/Empty Detection
//=============================================================================
wire [ADDR_WIDTH:0] wr_ptr_bin_sync = gray2bin(wr_ptr_gray_sync2);
wire [ADDR_WIDTH:0] rd_ptr_bin_sync = gray2bin(rd_ptr_gray_sync2);

always @(posedge wr_clk or negedge wr_rstn) begin
    if (!wr_rstn) begin
        wr_full <= 1'b0;
    end else begin
        wr_full <= ((wr_ptr_bin[ADDR_WIDTH] != rd_ptr_bin_sync[ADDR_WIDTH]) &&
                    (wr_ptr_bin[ADDR_WIDTH-1:0] == rd_ptr_bin_sync[ADDR_WIDTH-1:0]));
    end
end

always @(posedge rd_clk or negedge rd_rstn) begin
    if (!rd_rstn) begin
        rd_empty <= 1'b1;
    end else begin
        rd_empty <= (rd_ptr_bin == wr_ptr_bin_sync);
    end
end

//=============================================================================
// Memory Write
//=============================================================================
always @(posedge wr_clk) begin
    if (wr_en && !wr_full) begin
        mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= wr_data;
    end
end

//=============================================================================
// Memory Read
//=============================================================================
always @(posedge rd_clk) begin
    if (rd_en && !rd_empty) begin
        rd_data <= mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
    end
end

endmodule
