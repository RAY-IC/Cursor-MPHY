//=============================================================================
// MIPI M-PHY Low-Speed Mode Processor
//=============================================================================
// Description: Low-Speed mode processing for LS-GEAR-A/B
//=============================================================================

module ls_processor (
    input  wire        clk,
    input  wire        rstn,
    
    // Configuration
    input  wire        ls_enable,
    input  wire        ls_gear_a,
    input  wire        ls_gear_b,
    
    // Low-Speed Clock
    input  wire        ls_clk,
    
    // TX Path
    input  wire [31:0] tx_data_in,
    input  wire        tx_valid_in,
    output wire        tx_ready_out,
    
    output wire [7:0]  ls_tx_data,
    output wire        ls_tx_valid,
    output wire        ls_tx_start,
    input  wire        ls_tx_ready,
    
    // RX Path
    input  wire [7:0]  ls_rx_data,
    input  wire        ls_rx_valid,
    input  wire        ls_rx_start,
    
    output wire [31:0] rx_data_out,
    output wire        rx_valid_out,
    input  wire        rx_ready_out
);

//=============================================================================
// Gear Selection
//=============================================================================
wire active_gear = ls_gear_a || ls_gear_b;

//=============================================================================
// TX Data Path: 32bit ? 8bit
//=============================================================================
reg [31:0] tx_data_buffer;
reg [2:0]  tx_byte_cnt;
reg        tx_active;

always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
        tx_data_buffer <= 32'h0;
        tx_byte_cnt <= 3'h0;
        tx_active <= 1'b0;
    end else if (ls_enable && active_gear) begin
        if (tx_valid_in && tx_ready_out) begin
            tx_data_buffer <= tx_data_in;
            tx_byte_cnt <= 3'h0;
            tx_active <= 1'b1;
        end else if (tx_active && ls_tx_ready) begin
            if (tx_byte_cnt == 3'h3) begin
                tx_active <= 1'b0;
            end
            tx_byte_cnt <= tx_byte_cnt + 1'b1;
        end
    end else begin
        tx_data_buffer <= 32'h0;
        tx_byte_cnt <= 3'h0;
        tx_active <= 1'b0;
    end
end

assign tx_ready_out = !tx_active || (tx_byte_cnt == 3'h3 && ls_tx_ready);

// Byte selection based on byte count
assign ls_tx_data = (tx_byte_cnt == 3'h0) ? tx_data_buffer[7:0]   :
                    (tx_byte_cnt == 3'h1) ? tx_data_buffer[15:8]  :
                    (tx_byte_cnt == 3'h2) ? tx_data_buffer[23:16] :
                                            tx_data_buffer[31:24];
assign ls_tx_valid = tx_active && ls_tx_ready;
assign ls_tx_start = (tx_byte_cnt == 3'h0) && tx_active;

//=============================================================================
// RX Data Path: 8bit ? 32bit
//=============================================================================
reg [31:0] rx_data_buffer;
reg [2:0]  rx_byte_cnt;
reg        rx_active;

always @(posedge ls_clk or negedge rstn) begin
    if (!rstn) begin
        rx_data_buffer <= 32'h0;
        rx_byte_cnt <= 3'h0;
        rx_active <= 1'b0;
    end else if (ls_enable && active_gear) begin
        if (ls_rx_start && ls_rx_valid) begin
            case (rx_byte_cnt)
                3'h0: rx_data_buffer[7:0]   <= ls_rx_data;
                3'h1: rx_data_buffer[15:8]  <= ls_rx_data;
                3'h2: rx_data_buffer[23:16] <= ls_rx_data;
                3'h3: rx_data_buffer[31:24] <= ls_rx_data;
            endcase
            rx_byte_cnt <= rx_byte_cnt + 1'b1;
            rx_active <= 1'b1;
        end else if (rx_active && ls_rx_valid) begin
            case (rx_byte_cnt)
                3'h0: rx_data_buffer[7:0]   <= ls_rx_data;
                3'h1: rx_data_buffer[15:8]  <= ls_rx_data;
                3'h2: rx_data_buffer[23:16] <= ls_rx_data;
                3'h3: begin
                    rx_data_buffer[31:24] <= ls_rx_data;
                    rx_byte_cnt <= 3'h0;
                end
            endcase
            if (rx_byte_cnt != 3'h3) begin
                rx_byte_cnt <= rx_byte_cnt + 1'b1;
            end
        end
    end else begin
        rx_data_buffer <= 32'h0;
        rx_byte_cnt <= 3'h0;
        rx_active <= 1'b0;
    end
end

assign rx_data_out = rx_data_buffer;
assign rx_valid_out = (rx_byte_cnt == 3'h0) && rx_active && (rx_byte_cnt == 3'h3);

// Note: Low-speed mode does not use 8b/10b encoding

endmodule
