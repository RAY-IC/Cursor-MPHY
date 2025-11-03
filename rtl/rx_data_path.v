//=============================================================================
// RX Data Path
//=============================================================================
// Description: Receive data path from HS/LS processors to RMMI interface
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
    
    // RMMI Internal Interface
    output wire [31:0] rmmi_rx_data,
    output wire        rmmi_rx_valid,
    input  wire        rmmi_rx_ready,
    output wire        rmmi_rx_sot,      // Start of Transfer
    output wire        rmmi_rx_eot,      // End of Transfer
    output wire [1:0]  rmmi_rx_data_type,
    
    // FIFO Status
    output wire        rx_fifo_full,
    output wire        rx_fifo_empty
);

//=============================================================================
// RX FIFO (for buffering received data)
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
    .rd_data(rmmi_rx_data),
    .rd_en(fifo_read_en),
    .rd_empty(fifo_empty)
);

assign fifo_read_en = rmmi_rx_ready && !fifo_empty;
assign rmmi_rx_valid = !fifo_empty;

assign rx_fifo_full = fifo_full;
assign rx_fifo_empty = fifo_empty;

//=============================================================================
// Data Input Mux (HS/LS Mode Selection)
//=============================================================================
assign fifo_data_in = hs_mode ? hs_rx_data : ls_rx_data;
assign fifo_write_en = (hs_mode && hs_rx_valid && !fifo_full) ||
                       (ls_mode && ls_rx_valid && !fifo_full);

assign hs_rx_ready = hs_mode && !fifo_full;
assign ls_rx_ready = ls_mode && !fifo_full;

//=============================================================================
// SOT/EOT Generation (Simplified - based on packet boundaries)
//=============================================================================
reg packet_active;
reg [1:0] rx_data_type_reg;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        packet_active <= 1'b0;
        rx_data_type_reg <= 2'h0;
    end else if (rx_enable) begin
        if (fifo_write_en && !packet_active) begin
            packet_active <= 1'b1;
            rx_data_type_reg <= 2'h0; // Assume data type 0 (data)
        end else if (fifo_read_en && packet_active && fifo_empty) begin
            packet_active <= 1'b0;
        end
    end else begin
        packet_active <= 1'b0;
    end
end

assign rmmi_rx_sot = !packet_active && fifo_write_en;
assign rmmi_rx_eot = packet_active && fifo_read_en && fifo_empty;
assign rmmi_rx_data_type = rx_data_type_reg;

endmodule
