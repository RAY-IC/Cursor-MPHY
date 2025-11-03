//=============================================================================
// MIPI M-PHY Digital Top Module
//=============================================================================
// Description: Top-level integration of all M-PHY digital modules
//              RMMI interface for primary data path
//              APB interface for configuration and debug only
//=============================================================================

module mphy_digital_top (
    // Clock and Reset
    input  wire        clk,
    input  wire        rstn,
    
    // APB3.0 Configuration Interface (Config/Debug ONLY)
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
    
    // RMMI Interface (PRIMARY DATA PATH)
    // RMMI TX (UniPro ? M-PHY)
    input  wire        rmmi_tx_clk,
    input  wire        rmmi_tx_req,
    output wire        rmmi_tx_ack,
    input  wire [31:0] rmmi_tx_data,
    input  wire        rmmi_tx_valid,
    output wire        rmmi_tx_ready,
    input  wire        rmmi_tx_sot,
    input  wire        rmmi_tx_eot,
    input  wire [1:0]  rmmi_tx_data_type,
    
    // RMMI RX (M-PHY ? UniPro)
    input  wire        rmmi_rx_clk,
    output wire        rmmi_rx_req,
    input  wire        rmmi_rx_ack,
    output wire [31:0] rmmi_rx_data,
    output wire        rmmi_rx_valid,
    input  wire        rmmi_rx_ready,
    output wire        rmmi_rx_sot,
    output wire        rmmi_rx_eot,
    output wire [1:0]  rmmi_rx_data_type,
    
    // RMMI Control
    input  wire        rmmi_rst_n,
    output wire [2:0]  rmmi_link_state,
    output wire        rmmi_link_active,
    output wire        rmmi_tx_active,
    output wire        rmmi_rx_active,
    output wire        rmmi_error,
    output wire [7:0]  rmmi_error_code,
    
    // Clock from Analog PHY PLL
    input  wire        hs_ref_clk,      // HS reference clock from PLL
    input  wire        ls_clk,          // LS clock
    
    // Analog PHY Interface - High Speed (16bit)
    output wire [15:0] hs_tx_data,
    output wire        hs_tx_clk,
    output wire        hs_tx_valid,
    output wire        hs_tx_start,
    output wire        hs_tx_end,
    input  wire        hs_tx_ready,
    
    input  wire [15:0] hs_rx_data,
    input  wire        hs_rx_clk,
    input  wire        hs_rx_valid,
    input  wire        hs_rx_start,
    input  wire        hs_rx_end,
    output wire        hs_rx_ready,
    
    // Analog PHY Interface - Low Speed (8bit)
    output wire [7:0]  ls_tx_data,
    output wire        ls_tx_clk,
    output wire        ls_tx_valid,
    output wire        ls_tx_start,
    input  wire        ls_tx_ready,
    
    input  wire [7:0]  ls_rx_data,
    input  wire        ls_rx_clk,
    input  wire        ls_rx_valid,
    input  wire        ls_rx_start,
    output wire        ls_rx_ready,
    
    // M-PHY Control Interface
    output wire [2:0]  mphy_state,
    output wire        mphy_hs_mode,
    output wire        mphy_ls_mode,
    input  wire        phy_pll_locked,
    
    // Calibration Interface (Reserved)
    output wire [31:0] cal_cfg_data,
    output wire        cal_cfg_valid,
    input  wire        cal_cfg_ready,
    input  wire [31:0] cal_status_data,
    input  wire        cal_status_valid,
    
    // Channel Processing Interface (Reserved)
    output wire [31:0] alg_cfg_data,
    output wire        alg_cfg_valid,
    input  wire        alg_cfg_ready,
    input  wire [31:0] alg_result_data,
    input  wire        alg_result_valid,
    
    // Interrupt
    output wire        interrupt
);

//=============================================================================
// Internal Signals
//=============================================================================
// APB Configuration Outputs
wire        mphy_enable;
wire        tx_enable;
wire        rx_enable;
wire        soft_reset;
wire        mode_sel;
wire [2:0]  hs_gear;
wire        ls_gear_a;
wire        ls_gear_b;
wire [31:0] interrupt_en;
wire        interrupt_clear;
wire        link_enable;

// Status Signals
wire        mphy_ready;
wire        tx_ready;
wire        rx_ready;
wire        tx_fifo_full;
wire        rx_fifo_empty;
wire [2:0]  current_state;
wire [31:0] interrupt_status;

// RMMI Internal Interface
wire [31:0] rmmi_int_tx_data;
wire        rmmi_int_tx_valid;
wire        rmmi_int_tx_ready;
wire        rmmi_int_tx_sot;
wire        rmmi_int_tx_eot;
wire [1:0]  rmmi_int_tx_data_type;

wire [31:0] rmmi_int_rx_data;
wire        rmmi_int_rx_valid;
wire        rmmi_int_rx_ready;
wire        rmmi_int_rx_sot;
wire        rmmi_int_rx_eot;
wire [1:0]  rmmi_int_rx_data_type;

// TX/RX Data Path Signals (between RMMI and HS/LS processors)
wire [31:0] tx_data_to_hs;
wire        tx_valid_to_hs;
wire        tx_ready_from_hs;
wire [31:0] tx_data_to_ls;
wire        tx_valid_to_ls;
wire        tx_ready_from_ls;

wire [31:0] rx_data_from_hs;
wire        rx_valid_from_hs;
wire        rx_ready_to_hs;
wire [31:0] rx_data_from_ls;
wire        rx_valid_from_ls;
wire        rx_ready_to_ls;

//=============================================================================
// APB Configuration Module
//=============================================================================
apb_config u_apb_config (
    .pclk(pclk),
    .presetn(presetn),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata),
    .prdata(prdata),
    .pready(pready),
    .pslverr(pslverr),
    
    .mphy_enable(mphy_enable),
    .tx_enable(tx_enable),
    .rx_enable(rx_enable),
    .soft_reset(soft_reset),
    .mode_sel(mode_sel),
    .hs_gear(hs_gear),
    .ls_gear_a(ls_gear_a),
    .ls_gear_b(ls_gear_b),
    .interrupt_en(interrupt_en),
    .link_enable(link_enable),
    
    .mphy_ready(mphy_ready),
    .tx_ready(tx_ready),
    .rx_ready(rx_ready),
    .tx_fifo_full(tx_fifo_full),
    .rx_fifo_empty(rx_fifo_empty),
    .current_state(current_state),
    .interrupt_status(interrupt_status),
    .interrupt_clear(interrupt_clear)
);

//=============================================================================
// M-PHY State Machine
//=============================================================================
mphy_state_machine u_mphy_state_machine (
    .clk(clk),
    .rstn(rstn & !soft_reset),
    
    .mphy_enable(mphy_enable),
    .mode_sel(mode_sel),
    .tx_enable(tx_enable),
    .rx_enable(rx_enable),
    .soft_reset(soft_reset),
    .hs_gear(hs_gear),
    .ls_gear_a(ls_gear_a),
    .ls_gear_b(ls_gear_b),
    
    .phy_pll_locked(phy_pll_locked),
    .hs_tx_ready(hs_tx_ready),
    .hs_rx_ready(hs_rx_ready),
    .ls_tx_ready(ls_tx_ready),
    .ls_rx_ready(ls_rx_ready),
    
    .current_state(current_state),
    .mphy_ready(mphy_ready),
    .tx_ready(tx_ready),
    .rx_ready(rx_ready),
    .mphy_hs_mode(mphy_hs_mode),
    .mphy_ls_mode(mphy_ls_mode),
    .mphy_state(mphy_state)
);

//=============================================================================
// RMMI Interface Module (PRIMARY DATA PATH)
//=============================================================================
rmmi_interface u_rmmi_interface (
    .clk(clk),
    .rstn(rstn & !soft_reset),
    
    .rmmi_tx_clk(rmmi_tx_clk),
    .rmmi_tx_req(rmmi_tx_req),
    .rmmi_tx_ack(rmmi_tx_ack),
    .rmmi_tx_data(rmmi_tx_data),
    .rmmi_tx_valid(rmmi_tx_valid),
    .rmmi_tx_ready(rmmi_tx_ready),
    .rmmi_tx_sot(rmmi_tx_sot),
    .rmmi_tx_eot(rmmi_tx_eot),
    .rmmi_tx_data_type(rmmi_tx_data_type),
    
    .rmmi_rx_clk(rmmi_rx_clk),
    .rmmi_rx_req(rmmi_rx_req),
    .rmmi_rx_ack(rmmi_rx_ack),
    .rmmi_rx_data(rmmi_rx_data),
    .rmmi_rx_valid(rmmi_rx_valid),
    .rmmi_rx_ready(rmmi_rx_ready),
    .rmmi_rx_sot(rmmi_rx_sot),
    .rmmi_rx_eot(rmmi_rx_eot),
    .rmmi_rx_data_type(rmmi_rx_data_type),
    
    .rmmi_rst_n(rmmi_rst_n),
    .rmmi_link_state(rmmi_link_state),
    .rmmi_link_active(rmmi_link_active),
    .rmmi_tx_active(rmmi_tx_active),
    .rmmi_rx_active(rmmi_rx_active),
    .rmmi_error(rmmi_error),
    .rmmi_error_code(rmmi_error_code),
    
    .int_tx_data(rmmi_int_tx_data),
    .int_tx_valid(rmmi_int_tx_valid),
    .int_tx_ready(rmmi_int_tx_ready),
    .int_tx_sot(rmmi_int_tx_sot),
    .int_tx_eot(rmmi_int_tx_eot),
    .int_tx_data_type(rmmi_int_tx_data_type),
    
    .int_rx_data(rmmi_int_rx_data),
    .int_rx_valid(rmmi_int_rx_valid),
    .int_rx_ready(rmmi_int_rx_ready),
    .int_rx_sot(rmmi_int_rx_sot),
    .int_rx_eot(rmmi_int_rx_eot),
    .int_rx_data_type(rmmi_int_rx_data_type),
    
    .mphy_ready(mphy_ready),
    .tx_enable(tx_enable),
    .rx_enable(rx_enable),
    .mphy_state(current_state),
    .link_enable(link_enable)
);

//=============================================================================
// TX Data Path (RMMI ? HS/LS Processor)
//=============================================================================
tx_data_path u_tx_data_path (
    .clk(clk),
    .rstn(rstn & !soft_reset),
    
    .tx_enable(tx_enable),
    .hs_mode(mphy_hs_mode),
    .ls_mode(mphy_ls_mode),
    
    // RMMI Internal Interface
    .rmmi_tx_data(rmmi_int_tx_data),
    .rmmi_tx_valid(rmmi_int_tx_valid),
    .rmmi_tx_ready(rmmi_int_tx_ready),
    .rmmi_tx_sot(rmmi_int_tx_sot),
    .rmmi_tx_eot(rmmi_int_tx_eot),
    
    .hs_tx_data(tx_data_to_hs),
    .hs_tx_valid(tx_valid_to_hs),
    .hs_tx_ready(tx_ready_from_hs),
    
    .ls_tx_data(tx_data_to_ls),
    .ls_tx_valid(tx_valid_to_ls),
    .ls_tx_ready(tx_ready_from_ls),
    
    .tx_fifo_full(tx_fifo_full),
    .tx_fifo_empty()
);

//=============================================================================
// RX Data Path (HS/LS Processor ? RMMI)
//=============================================================================
rx_data_path u_rx_data_path (
    .clk(clk),
    .rstn(rstn & !soft_reset),
    
    .rx_enable(rx_enable),
    .hs_mode(mphy_hs_mode),
    .ls_mode(mphy_ls_mode),
    
    .hs_rx_data(rx_data_from_hs),
    .hs_rx_valid(rx_valid_from_hs),
    .hs_rx_ready(rx_ready_to_hs),
    
    .ls_rx_data(rx_data_from_ls),
    .ls_rx_valid(rx_valid_from_ls),
    .ls_rx_ready(rx_ready_to_ls),
    
    // RMMI Internal Interface
    .rmmi_rx_data(rmmi_int_rx_data),
    .rmmi_rx_valid(rmmi_int_rx_valid),
    .rmmi_rx_ready(rmmi_int_rx_ready),
    .rmmi_rx_sot(rmmi_int_rx_sot),
    .rmmi_rx_eot(rmmi_int_rx_eot),
    
    .rx_fifo_full(),
    .rx_fifo_empty(rx_fifo_empty)
);

//=============================================================================
// High-Speed Mode Processor
//=============================================================================
hs_processor u_hs_processor (
    .clk(clk),
    .rstn(rstn & !soft_reset),
    
    .hs_enable(mphy_hs_mode && tx_ready),
    .hs_gear(hs_gear),
    .hs_ref_clk(hs_ref_clk),
    .hs_rx_clk(hs_rx_clk),
    
    .tx_data_in(tx_data_to_hs),
    .tx_valid_in(tx_valid_to_hs),
    .tx_ready_out(tx_ready_from_hs),
    
    .hs_tx_data(hs_tx_data),
    .hs_tx_valid(hs_tx_valid),
    .hs_tx_start(hs_tx_start),
    .hs_tx_end(hs_tx_end),
    .hs_tx_ready(hs_tx_ready),
    
    .hs_rx_data(hs_rx_data),
    .hs_rx_valid(hs_rx_valid),
    .hs_rx_start(hs_rx_start),
    .hs_rx_end(hs_rx_end),
    
    .rx_data_out(rx_data_from_hs),
    .rx_valid_out(rx_valid_from_hs),
    .rx_ready_out(rx_ready_to_hs)
);

// Assign TX clock (from HS processor or directly from ref_clk)
assign hs_tx_clk = hs_ref_clk; // Simplified - actual implementation may differ

//=============================================================================
// Low-Speed Mode Processor
//=============================================================================
ls_processor u_ls_processor (
    .clk(clk),
    .rstn(rstn & !soft_reset),
    
    .ls_enable(mphy_ls_mode && tx_ready),
    .ls_gear_a(ls_gear_a),
    .ls_gear_b(ls_gear_b),
    .ls_clk(ls_clk),
    
    .tx_data_in(tx_data_to_ls),
    .tx_valid_in(tx_valid_to_ls),
    .tx_ready_out(tx_ready_from_ls),
    
    .ls_tx_data(ls_tx_data),
    .ls_tx_valid(ls_tx_valid),
    .ls_tx_start(ls_tx_start),
    .ls_tx_ready(ls_tx_ready),
    
    .ls_rx_data(ls_rx_data),
    .ls_rx_valid(ls_rx_valid),
    .ls_rx_start(ls_rx_start),
    
    .rx_data_out(rx_data_from_ls),
    .rx_valid_out(rx_valid_from_ls),
    .rx_ready_out(rx_ready_to_ls)
);

assign ls_tx_clk = ls_clk;

//=============================================================================
// Interrupt Generation
//=============================================================================
assign interrupt_status = {
    28'h0,
    rx_fifo_empty,
    tx_fifo_full,
    rx_ready,
    tx_ready
};

assign interrupt = |(interrupt_status & interrupt_en);

//=============================================================================
// Reserved Interface Connections (Calibration & Algorithm)
//=============================================================================
// These are placeholders for future implementation
assign cal_cfg_data = 32'h0;
assign cal_cfg_valid = 1'b0;

assign alg_cfg_data = 32'h0;
assign alg_cfg_valid = 1'b0;

endmodule
