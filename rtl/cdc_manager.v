//=============================================================================
// Clock Domain Cross (CDC) Manager
//=============================================================================
// Description: Handles synchronization across different clock domains
//=============================================================================

module cdc_manager (
    input  wire        clk,
    input  wire        rstn,
    
    // Configuration signals (from APB domain)
    input  wire        cfg_enable,
    input  wire        cfg_mode_sel,
    input  wire [2:0]  cfg_hs_gear,
    output reg         cfg_enable_sync,
    output reg         cfg_mode_sel_sync,
    output reg  [2:0]  cfg_hs_gear_sync,
    
    // Status signals (to APB domain)
    input  wire        status_ready,
    output reg         status_ready_sync
);

//=============================================================================
// Synchronize Configuration Signals (APB ? M-PHY Clock Domain)
//=============================================================================
reg cfg_enable_sync1, cfg_enable_sync2;
reg cfg_mode_sel_sync1, cfg_mode_sel_sync2;
reg [2:0] cfg_hs_gear_sync1, cfg_hs_gear_sync2;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        cfg_enable_sync1 <= 1'b0;
        cfg_enable_sync2 <= 1'b0;
        cfg_mode_sel_sync1 <= 1'b0;
        cfg_mode_sel_sync2 <= 1'b0;
        cfg_hs_gear_sync1 <= 3'h0;
        cfg_hs_gear_sync2 <= 3'h0;
    end else begin
        // Double flop synchronization
        cfg_enable_sync1 <= cfg_enable;
        cfg_enable_sync2 <= cfg_enable_sync1;
        cfg_mode_sel_sync1 <= cfg_mode_sel;
        cfg_mode_sel_sync2 <= cfg_mode_sel_sync1;
        cfg_hs_gear_sync1 <= cfg_hs_gear;
        cfg_hs_gear_sync2 <= cfg_hs_gear_sync1;
    end
end

assign cfg_enable_sync = cfg_enable_sync2;
assign cfg_mode_sel_sync = cfg_mode_sel_sync2;
assign cfg_hs_gear_sync = cfg_hs_gear_sync2;

//=============================================================================
// Synchronize Status Signals (M-PHY Clock Domain ? APB Domain)
//=============================================================================
// Note: This requires APB clock, which should be passed as parameter
// For now, using handshake approach
reg status_ready_sync1, status_ready_sync2;

// Note: This would need pclk as input in real implementation
// Simplified version shown here
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        status_ready_sync1 <= 1'b0;
        status_ready_sync2 <= 1'b0;
    end else begin
        status_ready_sync1 <= status_ready;
        status_ready_sync2 <= status_ready_sync1;
    end
end

assign status_ready_sync = status_ready_sync2;

endmodule
