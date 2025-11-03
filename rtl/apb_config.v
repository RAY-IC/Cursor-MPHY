//=============================================================================
// MIPI M-PHY APB3.0 Configuration Module
//=============================================================================
// Description: APB3.0 slave interface for configuration and status registers
//=============================================================================

module apb_config (
    // APB Interface
    input  wire        pclk,
    input  wire        presetn,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] paddr,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output reg         pready,
    output reg         pslverr,
    
    // Configuration Outputs
    output reg         mphy_enable,
    output reg         tx_enable,
    output reg         rx_enable,
    output reg         soft_reset,
    output reg         mode_sel,        // 0=LS, 1=HS
    output reg  [2:0]  hs_gear,         // 1-5
    output reg         ls_gear_a,
    output reg         ls_gear_b,
    output reg  [31:0] interrupt_en,
    output reg         link_enable,
    
    // Status Inputs
    input  wire        mphy_ready,
    input  wire        tx_ready,
    input  wire        rx_ready,
    input  wire        tx_fifo_full,
    input  wire        rx_fifo_empty,
    input  wire [2:0]  current_state,
    input  wire [31:0] interrupt_status,
    
    // Interrupt Clear
    output reg         interrupt_clear
);

//=============================================================================
// Register Address Definitions
//=============================================================================
localparam ADDR_CTRL_REG        = 10'h000; // 0x00
localparam ADDR_STATUS_REG      = 10'h001; // 0x04
localparam ADDR_MODE_REG        = 10'h002; // 0x08
localparam ADDR_TX_CONFIG       = 10'h003; // 0x0C
localparam ADDR_RX_CONFIG       = 10'h004; // 0x10
localparam ADDR_HS_GEAR         = 10'h005; // 0x14
localparam ADDR_LS_GEAR         = 10'h006; // 0x18
localparam ADDR_INTERRUPT_EN    = 10'h007; // 0x1C
localparam ADDR_INTERRUPT_STATUS = 10'h008; // 0x20

// Address space: 4KB (0x000 - 0xFFF)
// Reserved addresses: 0x24-0xFC for calibration and algorithm

//=============================================================================
// Internal Registers
//=============================================================================
reg [31:0] ctrl_reg;
reg [31:0] mode_reg;
reg [31:0] tx_config;
reg [31:0] rx_config;
reg [31:0] hs_gear_reg;
reg [31:0] ls_gear_reg;

//=============================================================================
// Address Decoder
//=============================================================================
wire [9:0] addr_word = paddr[11:2]; // Word address (4-byte aligned)

wire addr_valid = (paddr < 32'h1000); // Within 4KB space
wire addr_reserved = (paddr >= 32'h024) && (paddr < 32'h100);

//=============================================================================
// APB Access Logic
//=============================================================================
always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        prdata <= 32'h0;
        pready <= 1'b0;
        pslverr <= 1'b0;
    end else begin
        pready <= 1'b0;
        pslverr <= 1'b0;
        
        if (psel && !penable) begin
            // Setup phase
            pready <= 1'b0;
        end else if (psel && penable) begin
            // Access phase
            pready <= 1'b1;
            
            if (!addr_valid || addr_reserved) begin
                pslverr <= 1'b1;
                prdata <= 32'h0;
            end else if (pwrite) begin
                // Write access
                case (addr_word)
                    ADDR_CTRL_REG: begin
                        ctrl_reg <= pwdata;
                    end
                    ADDR_MODE_REG: begin
                        mode_reg <= pwdata;
                    end
                    ADDR_TX_CONFIG: begin
                        tx_config <= pwdata;
                    end
                    ADDR_RX_CONFIG: begin
                        rx_config <= pwdata;
                    end
                    ADDR_HS_GEAR: begin
                        hs_gear_reg <= pwdata;
                    end
                    ADDR_LS_GEAR: begin
                        ls_gear_reg <= pwdata;
                    end
                    ADDR_INTERRUPT_EN: begin
                        interrupt_en <= pwdata;
                    end
                    ADDR_INTERRUPT_STATUS: begin
                        // W1C - write 1 to clear
                        interrupt_clear <= |pwdata;
                    end
                    default: begin
                        // Reserved registers - write ignored
                    end
                endcase
            end else begin
                // Read access
                case (addr_word)
                    ADDR_CTRL_REG: begin
                        prdata <= ctrl_reg;
                    end
                    ADDR_STATUS_REG: begin
                        prdata <= {24'h0, current_state, rx_fifo_empty, 
                                   tx_fifo_full, rx_ready, tx_ready, mphy_ready};
                    end
                    ADDR_MODE_REG: begin
                        prdata <= mode_reg;
                    end
                    ADDR_TX_CONFIG: begin
                        prdata <= tx_config;
                    end
                    ADDR_RX_CONFIG: begin
                        prdata <= rx_config;
                    end
                    ADDR_HS_GEAR: begin
                        prdata <= hs_gear_reg;
                    end
                    ADDR_LS_GEAR: begin
                        prdata <= ls_gear_reg;
                    end
                    ADDR_INTERRUPT_EN: begin
                        prdata <= interrupt_en;
                    end
                    ADDR_INTERRUPT_STATUS: begin
                        prdata <= interrupt_status;
                    end
                    default: begin
                        prdata <= 32'h0;
                    end
                endcase
            end
        end
    end
end

//=============================================================================
// Register Outputs
//=============================================================================
always @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
        mphy_enable <= 1'b0;
        tx_enable <= 1'b0;
        rx_enable <= 1'b0;
        soft_reset <= 1'b0;
        mode_sel <= 1'b0;
        hs_gear <= 3'h1;
        ls_gear_a <= 1'b0;
        ls_gear_b <= 1'b0;
        interrupt_en <= 32'h0;
        link_enable <= 1'b0;
        interrupt_clear <= 1'b0;
    end else begin
        // Control Register [0x00]
        mphy_enable <= ctrl_reg[0];
        tx_enable <= ctrl_reg[1];
        rx_enable <= ctrl_reg[2];
        soft_reset <= ctrl_reg[3];
        link_enable <= ctrl_reg[4];
        
        // Mode Register [0x08]
        mode_sel <= mode_reg[0];
        hs_gear <= mode_reg[7:4]; // Only lower 3 bits used (1-5)
        ls_gear_a <= mode_reg[8];
        ls_gear_b <= mode_reg[9];
        
        // Interrupt clear - single cycle pulse
        if (interrupt_clear) begin
            interrupt_clear <= 1'b0;
        end
    end
end

endmodule
