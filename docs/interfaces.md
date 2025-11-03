# MIPI M-PHY Interface Definition Document

## 1. RMMI Interface (Primary Data Path)

### 1.1 Overview
RMMI (Reduced Media Independent Interface) is the primary data path interface connecting UniPro controller to M-PHY digital section. All data communication uses this interface.

### 1.2 RMMI TX Interface (UniPro ? M-PHY)

```verilog
// RMMI TX Interface
input  wire        rmmi_tx_clk,        // RMMI TX clock
input  wire        rmmi_tx_req,        // TX request from UniPro
output wire        rmmi_tx_ack,        // TX acknowledge to UniPro
input  wire [31:0] rmmi_tx_data,       // TX data (32bit)
input  wire        rmmi_tx_valid,      // TX data valid
output wire        rmmi_tx_ready,       // TX ready (backpressure)
input  wire        rmmi_tx_sot,         // Start of Transfer
input  wire        rmmi_tx_eot,         // End of Transfer
input  wire [1:0]  rmmi_tx_data_type   // Data type (00=data, 01=control, etc.)
```

### 1.3 RMMI RX Interface (M-PHY ? UniPro)

```verilog
// RMMI RX Interface
input  wire        rmmi_rx_clk,        // RMMI RX clock
output wire        rmmi_rx_req,        // RX request to UniPro
input  wire        rmmi_rx_ack,        // RX acknowledge from UniPro
output wire [31:0] rmmi_rx_data,       // RX data (32bit)
output wire        rmmi_rx_valid,       // RX data valid
input  wire        rmmi_rx_ready,      // RX ready (backpressure)
output wire        rmmi_rx_sot,        // Start of Transfer
output wire        rmmi_rx_eot,        // End of Transfer
output wire [1:0]  rmmi_rx_data_type   // Data type
```

### 1.4 RMMI Control Interface

```verilog
// RMMI Control and Status
input  wire        rmmi_rst_n,         // RMMI reset (active low)
output wire [2:0]  rmmi_link_state,    // Link state (idle, active, etc.)
output wire        rmmi_link_active,   // Link active indicator
output wire        rmmi_tx_active,    // TX active indicator
output wire        rmmi_rx_active,     // RX active indicator
output wire        rmmi_error,         // Error indicator
output wire [7:0]  rmmi_error_code     // Error code
```

## 2. APB3.0 Configuration Interface (Config/Debug Only)

### 2.1 Overview
APB3.0 interface is used **ONLY** for configuration and debugging. It does NOT handle data traffic.

### 2.2 APB Signal Definition

```verilog
// APB3.0 Slave Interface
input  wire        pclk,           // APB clock (config domain)
input  wire        presetn,        // APB reset (active low)
input  wire        psel,           // Peripheral select
input  wire        penable,        // Enable signal
input  wire        pwrite,         // Read/Write control (1=write, 0=read)
input  wire [31:0] paddr,          // Address (byte address, 4-byte aligned)
input  wire [31:0] pwdata,         // Write data
output reg  [31:0] prdata,         // Read data
output reg         pready,         // Ready signal
output reg         pslverr         // Error signal
```

### 2.3 Register Map

| Address | Name | Width | R/W | Description |
|---------|------|-------|-----|-------------|
| 0x00 | CTRL_REG | 32 | R/W | Control register |
| 0x04 | STATUS_REG | 32 | R | Status register |
| 0x08 | MODE_REG | 32 | R/W | Mode configuration (HS/LS, GEAR selection) |
| 0x0C | TX_CONFIG | 32 | R/W | TX configuration |
| 0x10 | RX_CONFIG | 32 | R/W | RX configuration |
| 0x14 | HS_GEAR | 32 | R/W | High-speed GEAR configuration (1-5) |
| 0x18 | LS_GEAR | 32 | R/W | Low-speed GEAR configuration (A/B) |
| 0x1C | INTERRUPT_EN | 32 | R/W | Interrupt enable |
| 0x20 | INTERRUPT_STATUS | 32 | R/W1C | Interrupt status |
| 0x24 | DEBUG_REG | 32 | R | Debug register (read-only) |
| 0x28 | FIFO_STATUS | 32 | R | FIFO status (read-only) |
| 0x2C | ERROR_STATUS | 32 | R/W1C | Error status register |
| 0x30-0xFC | RESERVED | - | - | Reserved (calibration, algorithm, etc.) |

#### CTRL_REG (0x00) Bit Field Definition
- [0]: enable - Enable M-PHY
- [1]: tx_enable - Enable TX
- [2]: rx_enable - Enable RX
- [3]: soft_reset - Soft reset
- [4]: link_enable - Enable link
- [31:5]: RESERVED

#### STATUS_REG (0x04) Bit Field Definition
- [0]: ready - M-PHY ready
- [1]: tx_ready - TX ready
- [2]: rx_ready - RX ready
- [3]: tx_fifo_full - TX FIFO full
- [4]: rx_fifo_empty - RX FIFO empty
- [7:5]: current_state - Current state (HIBERN8, SLEEP, STALL, HS-BURST, LS-BURST)
- [15:8]: RESERVED
- [23:16]: link_status - Link status bits
- [31:24]: RESERVED

#### MODE_REG (0x08) Bit Field Definition
- [0]: mode_sel - Mode selection (0=LS, 1=HS)
- [3:1]: RESERVED
- [7:4]: hs_gear - HS GEAR (1-5)
- [8]: ls_gear_a - LS GEAR-A enable
- [9]: ls_gear_b - LS GEAR-B enable
- [31:10]: RESERVED

#### DEBUG_REG (0x24) Bit Field Definition (Read-Only)
- [7:0]: tx_packet_count - TX packet counter
- [15:8]: rx_packet_count - RX packet counter
- [23:16]: tx_byte_count_low - TX byte count [7:0]
- [31:24]: tx_byte_count_high - TX byte count [15:8]

#### FIFO_STATUS (0x28) Bit Field Definition (Read-Only)
- [7:0]: tx_fifo_usage - TX FIFO usage level
- [15:8]: rx_fifo_usage - RX FIFO usage level
- [31:16]: RESERVED

## 3. Analog PHY Interface

### 3.1 High-Speed Mode Interface (16bit)

```verilog
// High-Speed TX Interface
output wire [15:0] hs_tx_data,     // 16bit TX data
output wire        hs_tx_clk,       // TX clock (output to PHY)
output wire        hs_tx_valid,     // Data valid
output wire        hs_tx_start,     // Burst start
output wire        hs_tx_end,       // Burst end
input  wire        hs_tx_ready,     // PHY ready

// High-Speed RX Interface
input  wire [15:0] hs_rx_data,      // 16bit RX data
input  wire        hs_rx_clk,       // RX clock (from PHY)
input  wire        hs_rx_valid,     // Data valid
input  wire        hs_rx_start,     // Burst start
input  wire        hs_rx_end,       // Burst end
output wire        hs_rx_ready      // Receive ready
```

### 3.2 Low-Speed Mode Interface (8bit)

```verilog
// Low-Speed TX Interface
output wire [7:0]  ls_tx_data,      // 8bit TX data
output wire        ls_tx_clk,       // TX clock
output wire        ls_tx_valid,     // Data valid
output wire        ls_tx_start,     // Transmission start
input  wire        ls_tx_ready,     // PHY ready

// Low-Speed RX Interface
input  wire [7:0]  ls_rx_data,       // 8bit RX data
input  wire        ls_rx_clk,       // RX clock
input  wire        ls_rx_valid,     // Data valid
input  wire        ls_rx_start,     // Transmission start
output wire        ls_rx_ready      // Receive ready
```

### 3.3 Control Signals

```verilog
// M-PHY Control Interface
output wire [2:0]  mphy_state,      // State output (to analog PHY)
output wire        mphy_hs_mode,    // HS mode indicator
output wire        mphy_ls_mode,    // LS mode indicator
input  wire        phy_pll_locked,  // PLL lock signal
input  wire        phy_cal_req,     // Calibration request (reserved)
output wire        phy_cal_ack      // Calibration acknowledge (reserved)
```

## 4. Clock and Reset

```verilog
// Clock and Reset
input  wire        clk,             // Main clock
input  wire        rstn,            // Main reset (active low)

// RMMI Clocks
input  wire        rmmi_tx_clk,     // RMMI TX clock
input  wire        rmmi_rx_clk,     // RMMI RX clock

// Clock from Analog PHY PLL
input  wire        hs_ref_clk,       // HS reference clock (from PLL)
input  wire        ls_clk,          // LS clock
```

## 5. Reserved Interfaces (Calibration and Algorithm)

### 5.1 Analog Calibration Interface (Reserved)

```verilog
// Analog Calibration Interface (Reserved)
output wire [31:0] cal_cfg_data,    // Calibration configuration data
output wire        cal_cfg_valid,   // Calibration configuration valid
input  wire        cal_cfg_ready,   // Calibration configuration ready
input  wire [31:0] cal_status_data, // Calibration status data
input  wire        cal_status_valid // Calibration status valid
```

### 5.2 Channel Processing Algorithm Interface (Reserved)

```verilog
// Channel Processing Algorithm Interface (Reserved)
output wire [31:0] alg_cfg_data,    // Algorithm configuration data
output wire        alg_cfg_valid,   // Algorithm configuration valid
input  wire        alg_cfg_ready,   // Algorithm configuration ready
input  wire [31:0] alg_result_data, // Algorithm result data
input  wire        alg_result_valid // Algorithm result valid
```

## 6. Interface Summary

| Interface | Purpose | Direction | Clock Domain | Data Width |
|-----------|---------|-----------|--------------|------------|
| RMMI | Primary data path | Bidirectional | RMMI clock | 32bit |
| APB3.0 | Configuration/Debug | Bidirectional | APB clock | 32bit |
| Analog PHY | PHY interface | Bidirectional | PHY clock | 16/8bit |
