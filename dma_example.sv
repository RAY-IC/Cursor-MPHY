//=============================================================================
// DMA Module Usage Example
// Example of how to instantiate and use the 2D DMA module
//=============================================================================

module dma_example (
    input  logic        clk,
    input  logic        rst_n,
    
    // AXI Master Interface (to memory/interconnect)
    // ... AXI signals ...
    
    // AXI Slave Interface (for register access)
    // ... AXI signals ...
);

    // Instantiate DMA module
    dma_2d_axi #(
        .AXI_ADDR_WIDTH(32),
        .AXI_DATA_WIDTH(64),
        .AXI_ID_WIDTH(4),
        .MAX_OUTSTANDING(8),
        .REG_ADDR_WIDTH(8)
    ) u_dma (
        .clk(clk),
        .rst_n(rst_n),
        
        // Connect AXI Master interface to memory bus
        // Connect AXI Slave interface to CPU/configuration bus
    );

    // Example: Configure DMA for 1920x1080 RGB888 image transfer
    // with 64x64 tiles
    //
    // Register writes (via AXI Slave interface):
    // 1. Write SRC_ADDR_REG (0x08) = source frame buffer address
    // 2. Write DST_ADDR_REG (0x0C) = destination frame buffer address
    // 3. Write FRAME_WIDTH (0x10) = 1920
    // 4. Write FRAME_HEIGHT (0x14) = 1080
    // 5. Write TILE_WIDTH (0x18) = 64
    // 6. Write TILE_HEIGHT (0x1C) = 64
    // 7. Write TILE_STRIDE (0x20) = 1920 * 3 = 5760 (bytes)
    // 8. Write PIXEL_STRIDE (0x24) = 3 (RGB888)
    // 9. Write TRANSFER_SIZE (0x28) = 3 (8 bytes, 64-bit AXI)
    // 10. Write CTRL_REG (0x00) bit[31] = 1 to start transfer
    //
    // Monitor STATUS_REG (0x04):
    // - bit[31] (done): transfer complete
    // - bit[30] (error): error occurred

endmodule
