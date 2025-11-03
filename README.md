# MIPI M-PHY Digital Section Design

## Project Overview

This project implements the digital section logic compliant with MIPI M-PHY 5.0 protocol, supporting high-speed mode (HS-GEAR-1 to HS-GEAR-5) and low-speed mode (LS-GEAR-A/B). The design uses **RMMI (Reduced Media Independent Interface)** as the primary data path for UniPro controller communication, and **APB3.0** as configuration and debug interface only.

## Project Structure

```
/workspace/
??? docs/                        # Design documents
?   ??? architecture.md         # Architecture design document
?   ??? interfaces.md           # Interface definition document
?   ??? microarchitecture.md    # Microarchitecture design document
?   ??? design_summary.md       # Design summary
??? rtl/                         # RTL source code
?   ??? apb_config.v            # APB3.0 configuration module (config/debug only)
?   ??? rmmi_interface.v         # RMMI interface module (PRIMARY DATA PATH)
?   ??? mphy_state_machine.v    # M-PHY state machine
?   ??? hs_processor.v          # High-speed mode processor
?   ??? ls_processor.v          # Low-speed mode processor
?   ??? tx_data_path.v          # TX data path (RMMI ? PHY)
?   ??? rx_data_path.v          # RX data path (PHY ? RMMI)
?   ??? async_fifo.v            # Async FIFO
?   ??? cdc_manager.v           # Clock domain cross manager
?   ??? mphy_digital_top.v      # Top-level module
??? tb/                          # Testbench
?   ??? mphy_digital_top_tb.v   # Top-level testbench
??? README.md                    # This file
```

## Key Features

1. **RMMI Interface (Primary Data Path)**
   - Bidirectional data communication with UniPro controller
   - TX path: UniPro ? M-PHY digital ? Analog PHY
   - RX path: Analog PHY ? M-PHY digital ? UniPro
   - Request/acknowledge handshake protocol
   - Start of Transfer (SOT) and End of Transfer (EOT) signals
   - Independent RMMI clock domain

2. **APB3.0 Interface (Configuration/Debug Only)**
   - **NOT used for data path** - configuration and debugging only
   - Standard APB3.0 slave interface
   - Register access for configuration
   - Status and debug register access
   - Independent APB clock domain

3. **MIPI M-PHY 5.0 Protocol Support**
   - Complete state machine (HIBERN8, SLEEP, STALL, HS-BURST, LS-BURST)
   - Mode switching support

4. **High-Speed Mode Support**
   - GEAR-1: 1458 Mbps
   - GEAR-2: 2917 Mbps
   - GEAR-3: 5834 Mbps
   - GEAR-4: 11668 Mbps
   - GEAR-5: 23336 Mbps
   - 16bit data width interface to analog PHY

5. **Low-Speed Mode Support**
   - LS-GEAR-A/B
   - 8bit data width interface to analog PHY

6. **Clock Domain Management**
   - Multiple independent clock domains (RMMI, APB, HS, LS)
   - Async FIFO for cross-clock domain data transfer
   - Synchronization logic for control signals

7. **Reserved Interfaces**
   - Analog calibration interface reserved
   - Channel processing algorithm interface reserved

## Interface Description

### RMMI Interface (Primary Data Path)

The RMMI interface is the **main data communication path** between UniPro controller and M-PHY.

**TX Path (UniPro ? M-PHY):**
- `rmmi_tx_clk`: RMMI TX clock
- `rmmi_tx_req/rmmi_tx_ack`: Request/acknowledge handshake
- `rmmi_tx_data[31:0]`: TX data (32bit)
- `rmmi_tx_valid/rmmi_tx_ready`: Data valid/ready signals
- `rmmi_tx_sot/rmmi_tx_eot`: Start/End of Transfer
- `rmmi_tx_data_type[1:0]`: Data type indication

**RX Path (M-PHY ? UniPro):**
- `rmmi_rx_clk`: RMMI RX clock
- `rmmi_rx_req/rmmi_rx_ack`: Request/acknowledge handshake
- `rmmi_rx_data[31:0]`: RX data (32bit)
- `rmmi_rx_valid/rmmi_rx_ready`: Data valid/ready signals
- `rmmi_rx_sot/rmmi_rx_eot`: Start/End of Transfer
- `rmmi_rx_data_type[1:0]`: Data type indication

### APB3.0 Configuration Interface (Config/Debug Only)

Standard APB3.0 slave interface for **configuration and debugging only**. Does NOT handle data traffic.

### Analog PHY Interface

#### High-Speed Mode (16bit)
- `hs_tx_data[15:0]`: TX data to analog PHY
- `hs_rx_data[15:0]`: RX data from analog PHY
- Clock and handshake signals

#### Low-Speed Mode (8bit)
- `ls_tx_data[7:0]`: TX data to analog PHY
- `ls_rx_data[7:0]`: RX data from analog PHY
- Clock and handshake signals

## Register Map (APB)

| Address | Name | Description |
|---------|------|-------------|
| 0x00 | CTRL_REG | Control register (enable, link_enable, etc.) |
| 0x04 | STATUS_REG | Status register |
| 0x08 | MODE_REG | Mode configuration register |
| 0x0C | TX_CONFIG | TX configuration register |
| 0x10 | RX_CONFIG | RX configuration register |
| 0x14 | HS_GEAR | High-speed GEAR configuration |
| 0x18 | LS_GEAR | Low-speed GEAR configuration |
| 0x1C | INTERRUPT_EN | Interrupt enable |
| 0x20 | INTERRUPT_STATUS | Interrupt status |
| 0x24 | DEBUG_REG | Debug register (read-only) |
| 0x28 | FIFO_STATUS | FIFO status (read-only) |
| 0x2C | ERROR_STATUS | Error status register |
| 0x30-0xFC | RESERVED | Reserved (calibration and algorithm) |

For detailed register definitions, please refer to `docs/interfaces.md`.

## Usage

### 1. Basic Configuration Flow (via APB)

1. After reset, M-PHY is in HIBERN8 state
2. Enable M-PHY by writing to CTRL_REG via APB, enter SLEEP state
3. Configure MODE_REG to select HS or LS mode
4. Configure corresponding GEAR register
5. Enable link (link_enable bit in CTRL_REG)
6. Enable TX or RX, enter BURST state

### 2. Data Communication (via RMMI)

**TX Data Path:**
1. UniPro controller asserts `rmmi_tx_req`
2. M-PHY asserts `rmmi_tx_ack`
3. UniPro sends data via `rmmi_tx_data` with `rmmi_tx_valid`
4. M-PHY processes data and sends to analog PHY

**RX Data Path:**
1. M-PHY receives data from analog PHY
2. M-PHY processes data and asserts `rmmi_rx_req`
3. UniPro controller asserts `rmmi_rx_ack`
4. M-PHY sends data via `rmmi_rx_data` with `rmmi_rx_valid`

### 3. High-Speed Mode Usage Example

```verilog
// Configure via APB (config/debug only)
apb_write(0x00, 32'h00000001); // Enable M-PHY
apb_write(0x08, 32'h00000011); // HS mode, GEAR=1
apb_write(0x00, 32'h00000013); // Enable + TX Enable + Link Enable

// Data communication via RMMI (primary data path)
// UniPro controller uses RMMI interface for all data traffic
```

## Clock Requirements

- **System Clock (clk)**: Internal processing clock
- **RMMI TX Clock (rmmi_tx_clk)**: RMMI TX clock domain
- **RMMI RX Clock (rmmi_rx_clk)**: RMMI RX clock domain
- **APB Clock (pclk)**: APB configuration clock (independent)
- **High-Speed Reference Clock (hs_ref_clk)**: From analog PHY PLL, frequency depends on GEAR selection
- **Low-Speed Clock (ls_clk)**: Low-speed mode clock

## Testing

Run testbench:

```bash
# Using VCS (example)
vcs -sverilog -f rtl_filelist.f rtl/*.v tb/mphy_digital_top_tb.v
simv

# Using QuestaSim (example)
vlog -sv rtl/*.v tb/mphy_digital_top_tb.v
vsim mphy_digital_top_tb
run -all
```

## Notes

1. **RMMI is Primary Data Path**: All data communication uses RMMI interface, not APB
2. **APB is Config/Debug Only**: APB interface is used only for configuration and debugging, not for data traffic
3. **8b/10b Encoder/Decoder**: Current implementation is simplified, actual application requires complete 8b/10b encoder/decoder IP
4. **Clock Generation**: Clock generation logic needs adjustment based on actual PLL configuration
5. **Timing Constraints**: Actual application requires appropriate timing constraints
6. **Calibration Interface**: Reserved calibration and algorithm interfaces need subsequent implementation

## Design Status

- ? Architecture design complete
- ? RMMI interface definition complete
- ? Interface definition complete
- ? Microarchitecture design complete
- ? RTL implementation complete
- ? Basic testbench complete
- ? Functional verification (in progress)
- ? Timing analysis (pending)
- ? Synthesis and implementation (pending)

## Author

Digital IC Design Team

## License

This project is an internal company project, all rights reserved.
