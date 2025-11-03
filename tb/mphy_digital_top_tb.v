//=============================================================================
// MIPI M-PHY Digital Top Testbench
//=============================================================================
// Description: Basic testbench framework for M-PHY digital top module
//=============================================================================

`timescale 1ns / 1ps

module mphy_digital_top_tb;

//=============================================================================
// Parameters
//=============================================================================
parameter CLK_PERIOD = 10;      // 100 MHz system clock
parameter PCLK_PERIOD = 20;     // 50 MHz APB clock

//=============================================================================
// Signals
//=============================================================================
// Clock and Reset
reg         clk;
reg         rstn;
reg         pclk;
reg         presetn;

// APB Interface
reg         psel;
reg         penable;
reg         pwrite;
reg  [31:0] paddr;
reg  [31:0] pwdata;
wire [31:0] prdata;
wire        pready;
wire        pslverr;

// Clock from Analog PHY
reg         hs_ref_clk;
reg         ls_clk;
reg         phy_pll_locked;

// Analog PHY Interface - HS
wire [15:0] hs_tx_data;
wire        hs_tx_clk;
wire        hs_tx_valid;
wire        hs_tx_start;
wire        hs_tx_end;
reg         hs_tx_ready;

reg  [15:0] hs_rx_data;
wire        hs_rx_clk;
wire        hs_rx_valid;
wire        hs_rx_start;
wire        hs_rx_end;
wire        hs_rx_ready;

// Analog PHY Interface - LS
wire [7:0]  ls_tx_data;
wire        ls_tx_clk;
wire        ls_tx_valid;
wire        ls_tx_start;
reg         ls_tx_ready;

reg  [7:0]  ls_rx_data;
wire        ls_rx_clk;
wire        ls_rx_valid;
wire        ls_rx_start;
wire        ls_rx_ready;

// Control
wire [2:0]  mphy_state;
wire        mphy_hs_mode;
wire        mphy_ls_mode;

// Reserved Interfaces
wire [31:0] cal_cfg_data;
wire        cal_cfg_valid;
reg         cal_cfg_ready;
reg  [31:0] cal_status_data;
reg         cal_status_valid;

wire [31:0] alg_cfg_data;
wire        alg_cfg_valid;
reg         alg_cfg_ready;
reg  [31:0] alg_result_data;
reg         alg_result_valid;

// User Interface
reg  [31:0] user_tx_data;
reg         user_tx_valid;
wire        user_tx_ready;

wire [31:0] user_rx_data;
wire        user_rx_valid;
reg         user_rx_ready;

// Interrupt
wire        interrupt;

//=============================================================================
// Clock Generation
//=============================================================================
initial begin
    clk = 0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

initial begin
    pclk = 0;
    forever #(PCLK_PERIOD/2) pclk = ~pclk;
end

initial begin
    hs_ref_clk = 0;
    forever #(0.34) hs_ref_clk = ~hs_ref_clk; // ~1.47 GHz for GEAR-1
end

initial begin
    ls_clk = 0;
    forever #(100) ls_clk = ~ls_clk; // 5 MHz LS clock
end

//=============================================================================
// Reset Generation
//=============================================================================
initial begin
    rstn = 0;
    presetn = 0;
    phy_pll_locked = 0;
    #100;
    rstn = 1;
    presetn = 1;
    #50;
    phy_pll_locked = 1;
end

//=============================================================================
// DUT Instantiation
//=============================================================================
mphy_digital_top u_dut (
    .clk(clk),
    .rstn(rstn),
    
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
    
    .hs_ref_clk(hs_ref_clk),
    .ls_clk(ls_clk),
    
    .hs_tx_data(hs_tx_data),
    .hs_tx_clk(hs_tx_clk),
    .hs_tx_valid(hs_tx_valid),
    .hs_tx_start(hs_tx_start),
    .hs_tx_end(hs_tx_end),
    .hs_tx_ready(hs_tx_ready),
    
    .hs_rx_data(hs_rx_data),
    .hs_rx_clk(hs_rx_clk),
    .hs_rx_valid(hs_rx_valid),
    .hs_rx_start(hs_rx_start),
    .hs_rx_end(hs_rx_end),
    .hs_rx_ready(hs_rx_ready),
    
    .ls_tx_data(ls_tx_data),
    .ls_tx_clk(ls_tx_clk),
    .ls_tx_valid(ls_tx_valid),
    .ls_tx_start(ls_tx_start),
    .ls_tx_ready(ls_tx_ready),
    
    .ls_rx_data(ls_rx_data),
    .ls_rx_clk(ls_rx_clk),
    .ls_rx_valid(ls_rx_valid),
    .ls_rx_start(ls_rx_start),
    .ls_rx_ready(ls_rx_ready),
    
    .mphy_state(mphy_state),
    .mphy_hs_mode(mphy_hs_mode),
    .mphy_ls_mode(mphy_ls_mode),
    .phy_pll_locked(phy_pll_locked),
    
    .cal_cfg_data(cal_cfg_data),
    .cal_cfg_valid(cal_cfg_valid),
    .cal_cfg_ready(cal_cfg_ready),
    .cal_status_data(cal_status_data),
    .cal_status_valid(cal_status_valid),
    
    .alg_cfg_data(alg_cfg_data),
    .alg_cfg_valid(alg_cfg_valid),
    .alg_cfg_ready(alg_cfg_ready),
    .alg_result_data(alg_result_data),
    .alg_result_valid(alg_result_valid),
    
    .user_tx_data(user_tx_data),
    .user_tx_valid(user_tx_valid),
    .user_tx_ready(user_tx_ready),
    
    .user_rx_data(user_rx_data),
    .user_rx_valid(user_rx_valid),
    .user_rx_ready(user_rx_ready),
    
    .interrupt(interrupt)
);

//=============================================================================
// APB Task for Register Write
//=============================================================================
task apb_write;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(posedge pclk);
        psel = 1'b1;
        penable = 1'b0;
        pwrite = 1'b1;
        paddr = addr;
        pwdata = data;
        
        @(posedge pclk);
        penable = 1'b1;
        
        @(posedge pclk);
        wait(pready);
        @(posedge pclk);
        psel = 1'b0;
        penable = 1'b0;
    end
endtask

//=============================================================================
// APB Task for Register Read
//=============================================================================
task apb_read;
    input [31:0] addr;
    output [31:0] data;
    begin
        @(posedge pclk);
        psel = 1'b1;
        penable = 1'b0;
        pwrite = 1'b0;
        paddr = addr;
        
        @(posedge pclk);
        penable = 1'b1;
        
        @(posedge pclk);
        wait(pready);
        data = prdata;
        @(posedge pclk);
        psel = 1'b0;
        penable = 1'b0;
    end
endtask

//=============================================================================
// Test Stimulus
//=============================================================================
initial begin
    // Initialize
    psel = 0;
    penable = 0;
    pwrite = 0;
    paddr = 0;
    pwdata = 0;
    hs_tx_ready = 1;
    ls_tx_ready = 1;
    cal_cfg_ready = 1;
    alg_cfg_ready = 1;
    user_tx_valid = 0;
    user_rx_ready = 1;
    
    wait(rstn && presetn);
    #100;
    
    $display("=== MIPI M-PHY Digital Testbench Started ===");
    
    // Test 1: Write Control Register - Enable M-PHY
    $display("Test 1: Enable M-PHY");
    apb_write(32'h00, 32'h00000001); // Enable
    #100;
    
    // Test 2: Configure HS Mode GEAR-1
    $display("Test 2: Configure HS Mode GEAR-1");
    apb_write(32'h08, 32'h00000011); // Mode=HS, GEAR=1
    apb_write(32'h14, 32'h00000001); // HS GEAR = 1
    #100;
    
    // Test 3: Enable TX
    $display("Test 3: Enable TX");
    apb_write(32'h00, 32'h00000003); // Enable + TX Enable
    #200;
    
    // Test 4: Send test data
    $display("Test 4: Send test data");
    @(posedge clk);
    user_tx_data = 32'h12345678;
    user_tx_valid = 1;
    wait(user_tx_ready);
    @(posedge clk);
    user_tx_valid = 0;
    
    #1000;
    
    $display("=== Test Complete ===");
    $finish;
end

//=============================================================================
// Monitor
//=============================================================================
always @(posedge clk) begin
    if (user_rx_valid && user_rx_ready) begin
        $display("Time %0t: Received data = 0x%h", $time, user_rx_data);
    end
end

always @(mphy_state) begin
    $display("Time %0t: M-PHY State changed to %d", $time, mphy_state);
end

endmodule
