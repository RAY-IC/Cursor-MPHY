# MIPI M-PHY Digital Section Design

## Project Overview

This project implements the digital section logic compliant with MIPI M-PHY 5.0 protocol, supporting high-speed mode (HS-GEAR-1 to HS-GEAR-5) and low-speed mode (LS-GEAR-A/B).

## Project Structure

```
/workspace/
??? docs/                        # Design documents
?   ??? architecture.md         # Architecture design document
?   ??? interfaces.md           # Interface definition document
?   ??? microarchitecture.md    # Microarchitecture design document
?   ??? design_summary.md       # Design summary
??? rtl/                         # RTL source code
?   ??? apb_config.v            # APB3.0 configuration module
?   ??? mphy_state_machine.v    # M-PHY state machine
?   ??? hs_processor.v          # High-speed mode processor
?   ??? ls_processor.v          # Low-speed mode processor
?   ??? tx_data_path.v          # TX data path
?   ??? rx_data_path.v          # RX data path
?   ??? async_fifo.v            # Async FIFO
?   ??? cdc_manager.v           # Clock domain cross manager
?   ??? mphy_digital_top.v      # Top-level module
??? tb/                          # Testbench
?   ??? mphy_digital_top_tb.v   # Top-level testbench
??? README.md                    # This file
```

## Key Features

1. **MIPI M-PHY 5.0 Protocol Support**
   - Complete state machine (HIBERN8, SLEEP, STALL, HS-BURST, LS-BURST)
   - Mode switching support

2. **High-Speed Mode Support**
   - GEAR-1: 1458 Mbps
   - GEAR-2: 2917 Mbps
   - GEAR-3: 5834 Mbps
   - GEAR-4: 11668 Mbps
   - GEAR-5: 23336 Mbps
   - 16bit data width interface

3. **Low-Speed Mode Support**
   - LS-GEAR-A/B
   - 8bit data width interface

4. **APB3.0 Configuration Interface**
   - Standard APB3.0 slave interface
   - 4KB address space
   - Complete register mapping

5. **Clock Domain Management**
   - Multi-clock domain support
   - Async FIFO for cross-clock domain data transfer
   - Synchronization logic for control signals

6. **Reserved Interfaces**
   - Analog calibration interface reserved
   - Channel processing algorithm interface reserved

## Interface Description

### APB3.0 Configuration Interface

Standard APB3.0 slave interface supporting 32bit address and data width.

### Analog PHY Interface

#### High-Speed Mode (16bit)
- `hs_tx_data[15:0]`: TX data
- `hs_rx_data[15:0]`: RX data
- Clock and handshake signals

#### Low-Speed Mode (8bit)
- `ls_tx_data[7:0]`: TX data
- `ls_rx_data[7:0]`: RX data
- Clock and handshake signals

### User Data Interface

32bit data width for upper layer protocol stack data exchange.

## Register Map

| Address | Name | Description |
|---------|------|-------------|
| 0x00 | CTRL_REG | Control register |
| 0x04 | STATUS_REG | Status register |
| 0x08 | MODE_REG | Mode configuration register |
| 0x0C | TX_CONFIG | TX configuration register |
| 0x10 | RX_CONFIG | RX configuration register |
| 0x14 | HS_GEAR | High-speed GEAR configuration |
| 0x18 | LS_GEAR | Low-speed GEAR configuration |
| 0x1C | INTERRUPT_EN | Interrupt enable |
| 0x20 | INTERRUPT_STATUS | Interrupt status |
| 0x24-0xFC | RESERVED | Reserved (calibration and algorithm) |

For detailed register definitions, please refer to `docs/interfaces.md`.

## Usage

### 1. Basic Configuration Flow

1. After reset, M-PHY is in HIBERN8 state
2. Enable M-PHY by writing to CTRL_REG via APB, enter SLEEP state
3. Configure MODE_REG to select HS or LS mode
4. Configure corresponding GEAR register
5. Enable TX or RX to enter BURST state

### 2. High-Speed Mode Usage Example

```verilog
// 1. Enable M-PHY
apb_write(0x00, 32'h00000001); // Enable

// 2. Configure HS mode GEAR-1
apb_write(0x08, 32'h00000011); // HS mode, GEAR=1

// 3. Enable TX
apb_write(0x00, 32'h00000003); // Enable + TX Enable
```

### 3. Low-Speed Mode Usage Example

```verilog
// 1. Enable M-PHY
apb_write(0x00, 32'h00000001); // Enable

// 2. Configure LS mode
apb_write(0x08, 32'h00000001); // LS mode, GEAR-A

// 3. Enable TX
apb_write(0x00, 32'h00000003); // Enable + TX Enable
```

## Clock Requirements

- **System Clock (clk)**: User clock domain
- **APB Clock (pclk)**: APB configuration clock
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

1. **8b/10b Encoder/Decoder**: Current implementation is simplified, actual application requires complete 8b/10b encoder/decoder IP
2. **Clock Generation**: Clock generation logic needs adjustment based on actual PLL configuration
3. **Timing Constraints**: Actual application requires appropriate timing constraints
4. **Calibration Interface**: Reserved calibration and algorithm interfaces need subsequent implementation

## Design Status

- ? Architecture design complete
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
