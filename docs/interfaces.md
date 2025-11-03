# MIPI M-PHY Interface Definition Document

## 1. APB3.0 Configuration Interface

### 1.1 APB Signal Definition

```verilog
// APB3.0 Master Interface
input  wire        pclk,           // APB clock
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

### 1.2 Register Map

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
| 0x24-0xFC | RESERVED | - | - | Reserved (calibration, algorithm, etc.) |
| 0x100+ | USER_DATA | - | R/W | User data registers (FIFO interface) |

#### CTRL_REG (0x00) Bit Field Definition
- [0]: enable - Enable M-PHY
- [1]: tx_enable - Enable TX
- [2]: rx_enable - Enable RX
- [3]: soft_reset - Soft reset
- [31:4]: RESERVED

#### STATUS_REG (0x04) Bit Field Definition
- [0]: ready - M-PHY ready
- [1]: tx_ready - TX ready
- [2]: rx_ready - RX ready
- [3]: tx_fifo_full - TX FIFO full
- [4]: rx_fifo_empty - RX FIFO empty
- [7:5]: current_state - Current state (HIBERN8, SLEEP, STALL, HS-BURST, LS-BURST)
- [31:8]: RESERVED

#### MODE_REG (0x08) Bit Field Definition
- [0]: mode_sel - Mode selection (0=LS, 1=HS)
- [3:1]: RESERVED
- [7:4]: hs_gear - HS GEAR (1-5)
- [8]: ls_gear_a - LS GEAR-A enable
- [9]: ls_gear_b - LS GEAR-B enable
- [31:10]: RESERVED

## 2. Analog PHY Interface

### 2.1 High-Speed Mode Interface (16bit)

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

### 2.2 Low-Speed Mode Interface (8bit)

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

### 2.3 Control Signals

```verilog
// M-PHY Control Interface
output wire [2:0]  mphy_state,      // State output (to analog PHY)
output wire        mphy_hs_mode,    // HS mode indicator
output wire        mphy_ls_mode,    // LS mode indicator
input  wire        phy_pll_locked,  // PLL lock signal
input  wire        phy_cal_req,     // Calibration request (reserved)
output wire        phy_cal_ack      // Calibration acknowledge (reserved)
```

## 3. User Data Interface (Reserved)

### 3.1 TX User Interface

```verilog
// User TX Interface
input  wire [31:0] user_tx_data,    // User TX data (32bit)
input  wire        user_tx_valid,   // User TX valid
output wire        user_tx_ready,   // User TX ready
```

### 3.2 RX User Interface

```verilog
// User RX Interface
output wire [31:0] user_rx_data,    // User RX data (32bit)
output wire        user_rx_valid,    // User RX valid
input  wire        user_rx_ready     // User RX ready
```

## 4. Reserved Interfaces (Calibration and Algorithm)

### 4.1 Analog Calibration Interface (Reserved)

```verilog
// Analog Calibration Interface (Reserved)
output wire [31:0] cal_cfg_data,    // Calibration configuration data
output wire        cal_cfg_valid,   // Calibration configuration valid
input  wire        cal_cfg_ready,   // Calibration configuration ready
input  wire [31:0] cal_status_data, // Calibration status data
input  wire        cal_status_valid // Calibration status valid
```

### 4.2 Channel Processing Algorithm Interface (Reserved)

```verilog
// Channel Processing Algorithm Interface (Reserved)
output wire [31:0] alg_cfg_data,    // Algorithm configuration data
output wire        alg_cfg_valid,   // Algorithm configuration valid
input  wire        alg_cfg_ready,   // Algorithm configuration ready
input  wire [31:0] alg_result_data, // Algorithm result data
input  wire        alg_result_valid // Algorithm result valid
```

## 5. Clock and Reset

```verilog
// Clock and Reset
input  wire        clk,             // Main clock
input  wire        rstn,            // Main reset (active low)

// Clock from Analog PHY PLL
input  wire        hs_ref_clk,       // HS reference clock (from PLL)
input  wire        ls_clk,          // LS clock
```
