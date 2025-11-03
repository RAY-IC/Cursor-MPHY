//=============================================================================
// MIPI M-PHY State Machine
//=============================================================================
// Description: M-PHY protocol state machine (M-PHY 5.0)
//=============================================================================

module mphy_state_machine (
    input  wire        clk,
    input  wire        rstn,
    
    // Configuration Inputs
    input  wire        mphy_enable,
    input  wire        mode_sel,        // 0=LS, 1=HS
    input  wire        tx_enable,
    input  wire        rx_enable,
    input  wire        soft_reset,
    input  wire [2:0]  hs_gear,
    input  wire        ls_gear_a,
    input  wire        ls_gear_b,
    
    // PHY Status
    input  wire        phy_pll_locked,
    input  wire        hs_tx_ready,
    input  wire        hs_rx_ready,
    input  wire        ls_tx_ready,
    input  wire        ls_rx_ready,
    
    // State Outputs
    output reg  [2:0]  current_state,
    output reg         mphy_ready,
    output reg         tx_ready,
    output reg         rx_ready,
    output reg         mphy_hs_mode,
    output reg         mphy_ls_mode,
    output reg  [2:0]  mphy_state      // Output to analog PHY
);

//=============================================================================
// State Definitions
//=============================================================================
localparam STATE_HIBERN8  = 3'h0;
localparam STATE_SLEEP    = 3'h1;
localparam STATE_STALL    = 3'h2;
localparam STATE_HS_BURST = 3'h3;
localparam STATE_LS_BURST = 3'h4;

//=============================================================================
// State Machine
//=============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        current_state <= STATE_HIBERN8;
        mphy_ready <= 1'b0;
        tx_ready <= 1'b0;
        rx_ready <= 1'b0;
        mphy_hs_mode <= 1'b0;
        mphy_ls_mode <= 1'b0;
        mphy_state <= STATE_HIBERN8;
    end else if (soft_reset) begin
        current_state <= STATE_HIBERN8;
        mphy_ready <= 1'b0;
        tx_ready <= 1'b0;
        rx_ready <= 1'b0;
        mphy_hs_mode <= 1'b0;
        mphy_ls_mode <= 1'b0;
        mphy_state <= STATE_HIBERN8;
    end else begin
        case (current_state)
            STATE_HIBERN8: begin
                mphy_ready <= 1'b0;
                tx_ready <= 1'b0;
                rx_ready <= 1'b0;
                mphy_hs_mode <= 1'b0;
                mphy_ls_mode <= 1'b0;
                mphy_state <= STATE_HIBERN8;
                
                if (mphy_enable && phy_pll_locked) begin
                    current_state <= STATE_SLEEP;
                end
            end
            
            STATE_SLEEP: begin
                mphy_ready <= 1'b1;
                tx_ready <= 1'b0;
                rx_ready <= 1'b0;
                mphy_hs_mode <= 1'b0;
                mphy_ls_mode <= 1'b0;
                mphy_state <= STATE_SLEEP;
                
                if (!mphy_enable) begin
                    current_state <= STATE_HIBERN8;
                end else if (tx_enable || rx_enable) begin
                    current_state <= STATE_STALL;
                end
            end
            
            STATE_STALL: begin
                mphy_ready <= 1'b1;
                mphy_state <= STATE_STALL;
                
                if (!mphy_enable) begin
                    current_state <= STATE_HIBERN8;
                    tx_ready <= 1'b0;
                    rx_ready <= 1'b0;
                    mphy_hs_mode <= 1'b0;
                    mphy_ls_mode <= 1'b0;
                end else if (mode_sel) begin
                    // HS Mode
                    if (hs_gear >= 3'h1 && hs_gear <= 3'h5 && phy_pll_locked) begin
                        current_state <= STATE_HS_BURST;
                        tx_ready <= tx_enable && hs_tx_ready;
                        rx_ready <= rx_enable && hs_rx_ready;
                        mphy_hs_mode <= 1'b1;
                        mphy_ls_mode <= 1'b0;
                    end
                end else begin
                    // LS Mode
                    if ((ls_gear_a || ls_gear_b) && phy_pll_locked) begin
                        current_state <= STATE_LS_BURST;
                        tx_ready <= tx_enable && ls_tx_ready;
                        rx_ready <= rx_enable && ls_rx_ready;
                        mphy_hs_mode <= 1'b0;
                        mphy_ls_mode <= 1'b1;
                    end
                end
            end
            
            STATE_HS_BURST: begin
                mphy_ready <= 1'b1;
                mphy_hs_mode <= 1'b1;
                mphy_ls_mode <= 1'b0;
                mphy_state <= STATE_HS_BURST;
                tx_ready <= tx_enable && hs_tx_ready;
                rx_ready <= rx_enable && hs_rx_ready;
                
                if (!mphy_enable || !tx_enable && !rx_enable) begin
                    current_state <= STATE_STALL;
                    tx_ready <= 1'b0;
                    rx_ready <= 1'b0;
                end else if (!mode_sel) begin
                    // Switch to LS mode
                    current_state <= STATE_STALL;
                    tx_ready <= 1'b0;
                    rx_ready <= 1'b0;
                    mphy_hs_mode <= 1'b0;
                end
            end
            
            STATE_LS_BURST: begin
                mphy_ready <= 1'b1;
                mphy_hs_mode <= 1'b0;
                mphy_ls_mode <= 1'b1;
                mphy_state <= STATE_LS_BURST;
                tx_ready <= tx_enable && ls_tx_ready;
                rx_ready <= rx_enable && ls_rx_ready;
                
                if (!mphy_enable || !tx_enable && !rx_enable) begin
                    current_state <= STATE_STALL;
                    tx_ready <= 1'b0;
                    rx_ready <= 1'b0;
                end else if (mode_sel) begin
                    // Switch to HS mode
                    current_state <= STATE_STALL;
                    tx_ready <= 1'b0;
                    rx_ready <= 1'b0;
                    mphy_ls_mode <= 1'b0;
                end
            end
            
            default: begin
                current_state <= STATE_HIBERN8;
                mphy_ready <= 1'b0;
                tx_ready <= 1'b0;
                rx_ready <= 1'b0;
                mphy_hs_mode <= 1'b0;
                mphy_ls_mode <= 1'b0;
                mphy_state <= STATE_HIBERN8;
            end
        endcase
    end
end

endmodule
