//=============================================================================
// 2D DMA Engine Module
// Supports 2D image transfers with configurable tile size
//=============================================================================

module dma_2d_engine #(
    parameter int AXI_ADDR_WIDTH = 32,
    parameter int AXI_DATA_WIDTH = 64,
    parameter int AXI_ID_WIDTH   = 4,
    parameter int MAX_OUTSTANDING = 8
)(
    // Clock and Reset
    input  logic                        clk,
    input  logic                        rst_n,

    // Control Interface
    input  logic                        start,
    output logic                        done,
    output logic                        error,

    // Configuration Registers
    input  logic [AXI_ADDR_WIDTH-1:0]  src_base_addr,
    input  logic [AXI_ADDR_WIDTH-1:0]  dst_base_addr,
    input  logic [15:0]                frame_width,      // Frame width in pixels
    input  logic [15:0]                frame_height,     // Frame height in pixels
    input  logic [15:0]                tile_width,       // Tile width in pixels
    input  logic [15:0]                tile_height,      // Tile height in pixels
    input  logic [15:0]                tile_stride,      // Stride between tiles in bytes
    input  logic [15:0]                pixel_stride,     // Bytes per pixel
    input  logic                        direction,        // 0: read from src, 1: write to dst (for full transfer, do read then write)
    input  logic [2:0]                  transfer_size,    // AXI transfer size (0=1B, 1=2B, 2=4B, 3=8B)

    // AXI Master Interface
    output logic                        axi_wr_req_valid,
    input  logic                        axi_wr_req_ready,
    output logic [AXI_ADDR_WIDTH-1:0]  axi_wr_addr,
    output logic [15:0]                axi_wr_length,
    output logic [2:0]                 axi_wr_size,
    output logic [AXI_ID_WIDTH-1:0]    axi_wr_id,

    output logic                        axi_wr_data_valid,
    input  logic                        axi_wr_data_ready,
    output logic [AXI_DATA_WIDTH-1:0]  axi_wr_data,
    output logic                        axi_wr_data_last,

    input  logic                        axi_wr_resp_valid,
    output logic                        axi_wr_resp_ready,
    input  logic [AXI_ID_WIDTH-1:0]    axi_wr_resp_id,
    input  logic [1:0]                 axi_wr_resp_status,

    output logic                        axi_rd_req_valid,
    input  logic                        axi_rd_req_ready,
    output logic [AXI_ADDR_WIDTH-1:0]  axi_rd_addr,
    output logic [15:0]                axi_rd_length,
    output logic [2:0]                 axi_rd_size,
    output logic [AXI_ID_WIDTH-1:0]    axi_rd_id,

    input  logic                        axi_rd_data_valid,
    output logic                        axi_rd_data_ready,
    input  logic [AXI_DATA_WIDTH-1:0]  axi_rd_data,
    input  logic                        axi_rd_data_last,
    input  logic [AXI_ID_WIDTH-1:0]    axi_rd_data_id,

    // Internal Buffer Interface (for data processing)
    output logic                        buf_wr_en,
    output logic [AXI_ADDR_WIDTH-1:0]  buf_wr_addr,
    output logic [AXI_DATA_WIDTH-1:0]  buf_wr_data,

    output logic                        buf_rd_en,
    output logic [AXI_ADDR_WIDTH-1:0]  buf_rd_addr,
    input  logic [AXI_DATA_WIDTH-1:0]  buf_rd_data
);

    // State Machine
    typedef enum logic [3:0] {
        IDLE,
        CALC_TILE_ADDR,
        SEND_RD_REQ,
        WAIT_RD_DATA,
        SEND_WR_REQ,
        WAIT_WR_DATA,
        WAIT_WR_RESP,
        NEXT_TILE,
        DONE_STATE,
        ERROR_STATE
    } state_t;

    state_t state, next_state;

    // Tile position counters
    logic [15:0] tile_x, tile_y;
    logic [15:0] num_tiles_x, num_tiles_y;
    logic [AXI_ADDR_WIDTH-1:0] current_src_addr, current_dst_addr;
    logic [AXI_ADDR_WIDTH-1:0] tile_src_addr, tile_dst_addr;
    
    // Transfer counters
    logic [15:0] bytes_per_tile;
    logic [15:0] beats_per_tile;
    logic [15:0] current_beat;
    logic [AXI_ID_WIDTH-1:0] transaction_id;
    logic [AXI_ID_WIDTH-1:0] outstanding_ids [MAX_OUTSTANDING-1:0];
    logic [$clog2(MAX_OUTSTANDING):0] outstanding_count;

    // Calculate number of tiles
    assign num_tiles_x = (frame_width + tile_width - 1) / tile_width;
    assign num_tiles_y = (frame_height + tile_height - 1) / tile_height;
    
    // Calculate bytes per tile
    assign bytes_per_tile = tile_width * tile_height * pixel_stride;
    
    // Calculate beats per tile (aligned to AXI data width)
    assign beats_per_tile = (bytes_per_tile + (AXI_DATA_WIDTH/8) - 1) / (AXI_DATA_WIDTH/8);

    // Calculate tile addresses
    always_comb begin
        // Source tile address: base + (tile_y * frame_width + tile_x * tile_width) * pixel_stride
        tile_src_addr = src_base_addr + 
                       ((tile_y * frame_width + tile_x * tile_width) * pixel_stride);
        
        // Destination tile address: base + (tile_y * tile_stride + tile_x * tile_width * pixel_stride)
        tile_dst_addr = dst_base_addr + 
                       (tile_y * tile_stride + tile_x * tile_width * pixel_stride);
    end

    // State machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tile_x <= '0;
            tile_y <= '0;
            current_beat <= '0;
            transaction_id <= '0;
            outstanding_count <= '0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        tile_x <= '0;
                        tile_y <= '0;
                        current_beat <= '0;
                        transaction_id <= '0;
                        outstanding_count <= '0;
                    end
                end
                
                CALC_TILE_ADDR: begin
                    current_src_addr <= tile_src_addr;
                    current_dst_addr <= tile_dst_addr;
                end
                
                SEND_RD_REQ: begin
                    if (axi_rd_req_valid && axi_rd_req_ready) begin
                        outstanding_count <= outstanding_count + 1;
                        transaction_id <= transaction_id + 1;
                    end
                end
                
                WAIT_RD_DATA: begin
                    if (axi_rd_data_valid && axi_rd_data_ready && axi_rd_data_last) begin
                        current_beat <= '0;
                    end else if (axi_rd_data_valid && axi_rd_data_ready) begin
                        current_beat <= current_beat + 1;
                    end
                end
                
                SEND_WR_REQ: begin
                    if (axi_wr_req_valid && axi_wr_req_ready) begin
                        outstanding_count <= outstanding_count + 1;
                        transaction_id <= transaction_id + 1;
                    end
                end
                
                WAIT_WR_DATA: begin
                    if (axi_wr_data_valid && axi_wr_data_ready && axi_wr_data_last) begin
                        current_beat <= '0;
                    end else if (axi_wr_data_valid && axi_wr_data_ready) begin
                        current_beat <= current_beat + 1;
                    end
                end
                
                WAIT_WR_RESP: begin
                    if (axi_wr_resp_valid && axi_wr_resp_ready) begin
                        outstanding_count <= outstanding_count - 1;
                    end
                end
                
                NEXT_TILE: begin
                    if (tile_x == num_tiles_x - 1) begin
                        tile_x <= '0;
                        tile_y <= tile_y + 1;
                    end else begin
                        tile_x <= tile_x + 1;
                    end
                    current_beat <= '0;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_TILE_ADDR;
                end
            end
            
            CALC_TILE_ADDR: begin
                // Always start with read if we have source address configured
                // For write-only mode, direction should be set appropriately
                next_state = SEND_RD_REQ;
            end
            
            SEND_RD_REQ: begin
                if (axi_rd_req_valid && axi_rd_req_ready) begin
                    next_state = WAIT_RD_DATA;
                end
            end
            
            WAIT_RD_DATA: begin
                if (axi_rd_data_valid && axi_rd_data_ready && axi_rd_data_last) begin
                    // Read complete, now write to destination
                    // For full DMA transfer: read from src, then write to dst
                    next_state = SEND_WR_REQ;
                end
                // Note: Read errors are checked via rresp signal in AXI Master
            end
            
            SEND_WR_REQ: begin
                if (axi_wr_req_valid && axi_wr_req_ready) begin
                    next_state = WAIT_WR_DATA;
                end
            end
            
            WAIT_WR_DATA: begin
                if (axi_wr_data_valid && axi_wr_data_ready && axi_wr_data_last) begin
                    next_state = WAIT_WR_RESP;
                end
            end
            
            WAIT_WR_RESP: begin
                if (axi_wr_resp_valid && axi_wr_resp_ready) begin
                    if (axi_wr_resp_status != 2'b00) begin
                        next_state = ERROR_STATE;
                    end else if (tile_x == num_tiles_x - 1 && tile_y == num_tiles_y - 1) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_state = NEXT_TILE;
                    end
                end
            end
            
            NEXT_TILE: begin
                next_state = CALC_TILE_ADDR;
            end
            
            DONE_STATE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            ERROR_STATE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Output assignments
    assign done = (state == DONE_STATE);
    assign error = (state == ERROR_STATE);

    // AXI Read Request
    assign axi_rd_req_valid = (state == SEND_RD_REQ) && (direction == 1'b0);
    assign axi_rd_addr = current_src_addr;
    assign axi_rd_length = beats_per_tile;
    assign axi_rd_size = transfer_size;
    assign axi_rd_id = transaction_id;

    // AXI Read Data
    assign axi_rd_data_ready = (state == WAIT_RD_DATA);
    assign buf_wr_en = axi_rd_data_valid && axi_rd_data_ready;
    assign buf_wr_addr = current_beat;
    assign buf_wr_data = axi_rd_data;

    // AXI Write Request
    assign axi_wr_req_valid = (state == SEND_WR_REQ) && (direction == 1'b1);
    assign axi_wr_addr = current_dst_addr;
    assign axi_wr_length = beats_per_tile;
    assign axi_wr_size = transfer_size;
    assign axi_wr_id = transaction_id;

    // AXI Write Data
    assign axi_wr_data_valid = (state == WAIT_WR_DATA) && buf_rd_en;
    assign axi_wr_data = buf_rd_data;
    assign axi_wr_data_last = (current_beat == beats_per_tile - 1);
    assign buf_rd_en = (state == WAIT_WR_DATA) && axi_wr_data_ready;
    assign buf_rd_addr = current_beat;

    // AXI Write Response
    assign axi_wr_resp_ready = (state == WAIT_WR_RESP);

endmodule
