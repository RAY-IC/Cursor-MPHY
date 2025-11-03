//=============================================================================
// RX Data Path
//=============================================================================
// Description: Receive data path with FIFO and data formatting
//=============================================================================

module rx_data_path (
    input  wire        clk,
    input  wire        rstn,
    
    // Configuration
    input  wire        rx_enable,
    input  wire        hs_mode,
    input  wire        ls_mode,
    
    // HS Mode Interface
    input  wire [31:0] hs_rx_data,
    input  wire        hs_rx_valid,
    output wire        hs_rx_ready,
    
    // LS Mode Interface
    input  wire [31:0] ls_rx_data,
    input  wire        ls_rx_valid,
    output wire        ls_rx_ready,
    
    // User Interface
    output wire [31:0] user_rx_data,
    output wire        user_rx_valid,
    input  wire        user_rx_ready,
    
    // FIFO Status
    output wire        rx_fifo_full,
    output wire        rx_fifo_empty
);

//=============================================================================
// RX FIFO
//=============================================================================
wire [31:0] fifo_data_in;
wire        fifo_read_en;
wire        fifo_write_en;
wire        fifo_full;
wire        fifo_empty;

async_fifo #(
    .DATA_WIDTH(32),
    .DEPTH(16)
) u_rx_fifo (
    .wr_clk(clk),  // In real design, this might be different clock
    .wr_rstn(rstn),
    .wr_data(fifo_data_in),
    .wr_en(fifo_write_en),
    .wr_full(fifo_full),
    
    .rd_clk(clk),
    .rd_rstn(rstn),
    .rd_data(user_rx_data),
    .rd_en(fifo_read_en),
    .rd_empty(fifo_empty)
);

assign fifo_read_en = user_rx_ready && !fifo_empty;
assign user_rx_valid = !fifo_empty;

assign rx_fifo_full = fifo_full;
assign rx_fifo_empty = fifo_empty;

//=============================================================================
// Data Input Mux
//=============================================================================
assign fifo_data_in = hs_mode ? hs_rx_data : ls_rx_data;
assign fifo_write_en = (hs_mode && hs_rx_valid && !fifo_full) ||
                       (ls_mode && ls_rx_valid && !fifo_full);

assign hs_rx_ready = hs_mode && !fifo_full;
assign ls_rx_ready = ls_mode && !fifo_full;

endmodule
