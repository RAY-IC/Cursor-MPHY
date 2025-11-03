//=============================================================================
// TX Data Path
//=============================================================================
// Description: Transmit data path from RMMI interface to HS/LS processors
//=============================================================================

module tx_data_path (
    input  wire        clk,
    input  wire        rstn,
    
    // Configuration
    input  wire        tx_enable,
    input  wire        hs_mode,
    input  wire        ls_mode,
    
    // RMMI Internal Interface
    input  wire [31:0] rmmi_tx_data,
    input  wire        rmmi_tx_valid,
    output wire        rmmi_tx_ready,
    input  wire        rmmi_tx_sot,      // Start of Transfer
    input  wire        rmmi_tx_eot,      // End of Transfer
    input  wire [1:0]  rmmi_tx_data_type,
    
    // HS Mode Interface
    output wire [31:0] hs_tx_data,
    output wire        hs_tx_valid,
    input  wire        hs_tx_ready,
    
    // LS Mode Interface
    output wire [31:0] ls_tx_data,
    output wire        ls_tx_valid,
    input  wire        ls_tx_ready,
    
    // FIFO Status
    output wire        tx_fifo_full,
    output wire        tx_fifo_empty
);

//=============================================================================
// TX FIFO (for buffering RMMI data)
//=============================================================================
wire [31:0] fifo_data_out;
wire        fifo_read_en;
wire        fifo_write_en;
wire        fifo_full;
wire        fifo_empty;

async_fifo #(
    .DATA_WIDTH(32),
    .DEPTH(16)
) u_tx_fifo (
    .wr_clk(clk),
    .wr_rstn(rstn),
    .wr_data(rmmi_tx_data),
    .wr_en(fifo_write_en),
    .wr_full(fifo_full),
    
    .rd_clk(clk),  // In real design, this might be different clock
    .rd_rstn(rstn),
    .rd_data(fifo_data_out),
    .rd_en(fifo_read_en),
    .rd_empty(fifo_empty)
);

assign fifo_write_en = rmmi_tx_valid && !fifo_full;
assign rmmi_tx_ready = !fifo_full;

assign tx_fifo_full = fifo_full;
assign tx_fifo_empty = fifo_empty;

//=============================================================================
// Data Output Mux (HS/LS Mode Selection)
//=============================================================================
assign fifo_read_en = (hs_mode && hs_tx_ready && !fifo_empty) ||
                      (ls_mode && ls_tx_ready && !fifo_empty);

assign hs_tx_data = fifo_data_out;
assign hs_tx_valid = hs_mode && !fifo_empty && fifo_read_en;

assign ls_tx_data = fifo_data_out;
assign ls_tx_valid = ls_mode && !fifo_empty && fifo_read_en;

// Note: SOT/EOT and data_type are handled at RMMI interface level
// This module focuses on data formatting and mode selection

endmodule
