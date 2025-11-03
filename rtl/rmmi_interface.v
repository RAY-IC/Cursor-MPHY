//=============================================================================
// RMMI (Reduced Media Independent Interface) Module
//=============================================================================
// Description: RMMI interface for UniPro controller communication
//              This is the PRIMARY data path interface
//=============================================================================

module rmmi_interface (
    // Clock and Reset
    input  wire        clk,
    input  wire        rstn,
    
    // RMMI TX Interface (UniPro ? M-PHY)
    input  wire        rmmi_tx_clk,
    input  wire        rmmi_tx_req,
    output reg         rmmi_tx_ack,
    input  wire [31:0] rmmi_tx_data,
    input  wire        rmmi_tx_valid,
    output wire        rmmi_tx_ready,
    input  wire        rmmi_tx_sot,      // Start of Transfer
    input  wire        rmmi_tx_eot,      // End of Transfer
    input  wire [1:0]  rmmi_tx_data_type,
    
    // RMMI RX Interface (M-PHY ? UniPro)
    input  wire        rmmi_rx_clk,
    output reg         rmmi_rx_req,
    input  wire        rmmi_rx_ack,
    output wire [31:0] rmmi_rx_data,
    output wire        rmmi_rx_valid,
    input  wire        rmmi_rx_ready,
    output wire        rmmi_rx_sot,
    output wire        rmmi_rx_eot,
    output wire [1:0]  rmmi_rx_data_type,
    
    // RMMI Control and Status
    input  wire        rmmi_rst_n,
    output reg  [2:0]  rmmi_link_state,
    output reg         rmmi_link_active,
    output reg         rmmi_tx_active,
    output reg         rmmi_rx_active,
    output reg         rmmi_error,
    output reg  [7:0]  rmmi_error_code,
    
    // Internal Data Path (to/from M-PHY processing)
    // TX Path (to M-PHY)
    output wire [31:0] int_tx_data,
    output wire        int_tx_valid,
    input  wire        int_tx_ready,
    output wire        int_tx_sot,
    output wire        int_tx_eot,
    output wire [1:0]  int_tx_data_type,
    
    // RX Path (from M-PHY)
    input  wire [31:0] int_rx_data,
    input  wire        int_rx_valid,
    output wire        int_rx_ready,
    input  wire        int_rx_sot,
    input  wire        int_rx_eot,
    input  wire [1:0]  int_rx_data_type,
    
    // Control from M-PHY State Machine
    input  wire        mphy_ready,
    input  wire        tx_enable,
    input  wire        rx_enable,
    input  wire [2:0]  mphy_state,
    
    // Configuration
    input  wire        link_enable
);

//=============================================================================
// Link State Definitions
//=============================================================================
localparam LINK_STATE_IDLE    = 3'h0;
localparam LINK_STATE_ACTIVE  = 3'h1;
localparam LINK_STATE_HIBERN8 = 3'h2;
localparam LINK_STATE_SLEEP   = 3'h3;
localparam LINK_STATE_ERROR   = 3'h7;

//=============================================================================
// TX Request/Acknowledge Handshake
//=============================================================================
always @(posedge rmmi_tx_clk or negedge rmmi_rst_n) begin
    if (!rmmi_rst_n) begin
        rmmi_tx_ack <= 1'b0;
    end else begin
        // Simple handshake: acknowledge when request is high and ready
        rmmi_tx_ack <= rmmi_tx_req && tx_enable && mphy_ready;
    end
end

//=============================================================================
// TX Data Path: RMMI ? Internal
//=============================================================================
// Cross clock domain from RMMI TX clock to internal clock
reg [31:0] tx_data_ff;
reg        tx_valid_ff;
reg        tx_sot_ff;
reg        tx_eot_ff;
reg [1:0]  tx_data_type_ff;
reg        tx_ready_sync1, tx_ready_sync2;

// Synchronize ready signal from internal clock to RMMI clock
always @(posedge rmmi_tx_clk or negedge rmmi_rst_n) begin
    if (!rmmi_rst_n) begin
        tx_ready_sync1 <= 1'b0;
        tx_ready_sync2 <= 1'b0;
    end else begin
        tx_ready_sync1 <= int_tx_ready;
        tx_ready_sync2 <= tx_ready_sync1;
    end
end

// Register RMMI TX signals
always @(posedge rmmi_tx_clk or negedge rmmi_rst_n) begin
    if (!rmmi_rst_n) begin
        tx_data_ff <= 32'h0;
        tx_valid_ff <= 1'b0;
        tx_sot_ff <= 1'b0;
        tx_eot_ff <= 1'b0;
        tx_data_type_ff <= 2'h0;
    end else if (tx_enable && mphy_ready) begin
        if (rmmi_tx_valid && tx_ready_sync2) begin
            tx_data_ff <= rmmi_tx_data;
            tx_valid_ff <= rmmi_tx_valid;
            tx_sot_ff <= rmmi_tx_sot;
            tx_eot_ff <= rmmi_tx_eot;
            tx_data_type_ff <= rmmi_tx_data_type;
        end else begin
            tx_valid_ff <= 1'b0;
        end
    end else begin
        tx_data_ff <= 32'h0;
        tx_valid_ff <= 1'b0;
        tx_sot_ff <= 1'b0;
        tx_eot_ff <= 1'b0;
        tx_data_type_ff <= 2'h0;
    end
end

// Output to internal data path (use async FIFO for CDC in real implementation)
assign int_tx_data = tx_data_ff;
assign int_tx_valid = tx_valid_ff && tx_ready_sync2;
assign int_tx_sot = tx_sot_ff;
assign int_tx_eot = tx_eot_ff;
assign int_tx_data_type = tx_data_type_ff;

assign rmmi_tx_ready = tx_ready_sync2 && tx_enable && mphy_ready;

//=============================================================================
// RX Request/Acknowledge Handshake
//=============================================================================
reg rx_req_reg;

always @(posedge rmmi_rx_clk or negedge rmmi_rst_n) begin
    if (!rmmi_rst_n) begin
        rx_req_reg <= 1'b0;
        rmmi_rx_req <= 1'b0;
    end else begin
        // Generate RX request when data is available
        rx_req_reg <= int_rx_valid && rx_enable;
        rmmi_rx_req <= rx_req_reg && !rmmi_rx_ack;
    end
end

//=============================================================================
// RX Data Path: Internal ? RMMI
//=============================================================================
// Cross clock domain from internal clock to RMMI RX clock
reg [31:0] rx_data_ff;
reg        rx_valid_ff;
reg        rx_sot_ff;
reg        rx_eot_ff;
reg [1:0]  rx_data_type_ff;
reg        rx_ready_sync1, rx_ready_sync2;

// Synchronize ready signal from RMMI clock to internal clock
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        rx_ready_sync1 <= 1'b0;
        rx_ready_sync2 <= 1'b0;
    end else begin
        rx_ready_sync1 <= rmmi_rx_ready;
        rx_ready_sync2 <= rx_ready_sync1;
    end
end

assign int_rx_ready = rx_ready_sync2 && rx_enable;

// Register internal RX signals
always @(posedge rmmi_rx_clk or negedge rmmi_rst_n) begin
    if (!rmmi_rst_n) begin
        rx_data_ff <= 32'h0;
        rx_valid_ff <= 1'b0;
        rx_sot_ff <= 1'b0;
        rx_eot_ff <= 1'b0;
        rx_data_type_ff <= 2'h0;
    end else if (rx_enable && mphy_ready) begin
        if (int_rx_valid && rx_ready_sync2) begin
            rx_data_ff <= int_rx_data;
            rx_valid_ff <= int_rx_valid;
            rx_sot_ff <= int_rx_sot;
            rx_eot_ff <= int_rx_eot;
            rx_data_type_ff <= int_rx_data_type;
        end else if (rmmi_rx_ready) begin
            rx_valid_ff <= 1'b0;
        end
    end else begin
        rx_data_ff <= 32'h0;
        rx_valid_ff <= 1'b0;
        rx_sot_ff <= 1'b0;
        rx_eot_ff <= 1'b0;
        rx_data_type_ff <= 2'h0;
    end
end

// Output to RMMI
assign rmmi_rx_data = rx_data_ff;
assign rmmi_rx_valid = rx_valid_ff && rx_enable;
assign rmmi_rx_sot = rx_sot_ff;
assign rmmi_rx_eot = rx_eot_ff;
assign rmmi_rx_data_type = rx_data_type_ff;

//=============================================================================
// Link State and Status
//=============================================================================
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        rmmi_link_state <= LINK_STATE_IDLE;
        rmmi_link_active <= 1'b0;
        rmmi_tx_active <= 1'b0;
        rmmi_rx_active <= 1'b0;
        rmmi_error <= 1'b0;
        rmmi_error_code <= 8'h0;
    end else begin
        rmmi_link_active <= link_enable && mphy_ready;
        rmmi_tx_active <= tx_enable && (rmmi_tx_req || tx_valid_ff);
        rmmi_rx_active <= rx_enable && (rx_valid_ff || int_rx_valid);
        
        // Map M-PHY state to RMMI link state
        case (mphy_state)
            3'h0: rmmi_link_state <= LINK_STATE_HIBERN8;  // HIBERN8
            3'h1: rmmi_link_state <= LINK_STATE_SLEEP;    // SLEEP
            3'h2: rmmi_link_state <= LINK_STATE_IDLE;     // STALL
            3'h3, 3'h4: rmmi_link_state <= LINK_STATE_ACTIVE; // HS-BURST or LS-BURST
            default: rmmi_link_state <= LINK_STATE_ERROR;
        endcase
        
        // Error detection (simplified)
        if (!mphy_ready && link_enable) begin
            rmmi_error <= 1'b1;
            rmmi_error_code <= 8'h01; // Link not ready
        end else begin
            rmmi_error <= 1'b0;
            rmmi_error_code <= 8'h0;
        end
    end
end

endmodule
