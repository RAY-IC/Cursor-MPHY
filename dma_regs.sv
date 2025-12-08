//=============================================================================
// DMA Register Definitions
// Memory-mapped register interface for DMA configuration
//=============================================================================

package dma_regs_pkg;

    // Register Address Map
    localparam int DMA_REG_BASE = 32'h0000_0000;
    
    localparam int DMA_CTRL_REG      = DMA_REG_BASE + 32'h00;
    localparam int DMA_STATUS_REG    = DMA_REG_BASE + 32'h04;
    localparam int DMA_SRC_ADDR_REG  = DMA_REG_BASE + 32'h08;
    localparam int DMA_DST_ADDR_REG  = DMA_REG_BASE + 32'h0C;
    localparam int DMA_FRAME_WIDTH   = DMA_REG_BASE + 32'h10;
    localparam int DMA_FRAME_HEIGHT   = DMA_REG_BASE + 32'h14;
    localparam int DMA_TILE_WIDTH     = DMA_REG_BASE + 32'h18;
    localparam int DMA_TILE_HEIGHT    = DMA_REG_BASE + 32'h1C;
    localparam int DMA_TILE_STRIDE    = DMA_REG_BASE + 32'h20;
    localparam int DMA_PIXEL_STRIDE   = DMA_REG_BASE + 32'h24;
    localparam int DMA_TRANSFER_SIZE  = DMA_REG_BASE + 32'h28;

    // Control Register Bits
    typedef struct packed {
        logic [30:0] reserved;
        logic        start;      // Bit 31: Start DMA transfer
    } dma_ctrl_reg_t;

    // Status Register Bits
    typedef struct packed {
        logic [29:0] reserved;
        logic        error;      // Bit 30: Error occurred
        logic        done;       // Bit 31: Transfer complete
    } dma_status_reg_t;

endpackage
