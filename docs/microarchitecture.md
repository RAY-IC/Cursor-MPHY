# MIPI M-PHY Microarchitecture Design Document

## 1. RMMI Interface Module

### 1.1 Functional Description
- Primary data path interface for UniPro controller communication
- Handles TX and RX data paths
- Manages request/acknowledge handshake protocol
- Cross-clock domain synchronization between RMMI clock and internal clock

### 1.2 Microarchitecture

```
RMMI TX Interface ? CDC ? TX FIFO ? Internal TX Path
RMMI RX Interface ? CDC ? RX FIFO ? Internal RX Path
```

### 1.3 Key Features
- Request/acknowledge handshake protocol
- Start of Transfer (SOT) and End of Transfer (EOT) signals
- Data type indication
- Link state management
- Error detection and reporting

## 2. APB3.0 Configuration Module (Config/Debug Only)

### 1.1 Functional Description
- **NOT used for data path** - configuration and debugging only
- Implements APB3.0 slave interface
- Manages configuration register bank
- Provides register read/write access for configuration and status

### 1.2 Microarchitecture

```
APB Interface ? Address Decoder ? Register Bank ? Control Signals
                                           ?
                                    Status Registers
```

### 1.3 Key Features
- Supports 32bit address and data width
- 4KB address space (0x000-0xFFF)
- Register access delay: 1 clock cycle (pready)
- Error handling: Address out of bounds returns pslverr
- Debug registers for monitoring

## 3. M-PHY State Machine

### 3.1 State Definitions
According to M-PHY 5.0 protocol:
- **HIBERN8**: Hibernation state (lowest power consumption)
- **SLEEP**: Sleep state
- **STALL**: Stall state
- **HS-BURST**: High-speed burst transmission
- **LS-BURST**: Low-speed transmission

### 3.2 State Transition Diagram

```
      RESET
        ?
    HIBERN8 ???????????????
        ?                  ?
    SLEEP ?????????????????
        ?
      STALL
     ?     ?
HS-BURST  LS-BURST
```

### 3.3 State Transition Conditions
- HIBERN8 ? SLEEP: Wake-up command
- SLEEP ? STALL: Enable command
- STALL ? HS-BURST: HS mode enable + GEAR configuration complete
- STALL ? LS-BURST: LS mode enable
- Any state ? HIBERN8: Disable command

## 4. High-Speed Mode Processor

### 4.1 GEAR Rate Table
| GEAR | Rate (Mbps/lane) | Clock Frequency |
|------|------------------|-----------------|
| 1    | 1458             | ~729 MHz        |
| 2    | 2917             | ~1458 MHz       |
| 3    | 5834             | ~2917 MHz       |
| 4    | 11668            | ~5834 MHz       |
| 5    | 23336            | ~11668 MHz      |

### 4.2 Data Processing Flow
1. **Data Packing**: 32bit RMMI data ? 16bit PHY data
2. **8b/10b Encoding**: Each 8bit data encoded to 10bit symbol
3. **GEAR Adaptation**: Data rate selection based on GEAR
4. **Clock Generation**: TX clock generation based on reference clock

### 4.3 Clock Domain Management
- RMMI clock domain (rmmi_tx_clk/rmmi_rx_clk)
- User clock domain (clk)
- HS reference clock domain (hs_ref_clk)
- TX clock domain (hs_tx_clk)
- RX clock domain (hs_rx_clk)

Use async FIFO for cross-clock domain data transfer.

## 5. Low-Speed Mode Processor

### 5.1 Features
- 8bit data width
- LS-GEAR-A: Standard low-speed
- LS-GEAR-B: Low-speed mode B (optional)

### 5.2 Data Processing
- Direct transmission, no 8b/10b encoding required
- Uses independent low-speed clock domain

## 6. TX Data Path

### 6.1 Functional Modules
1. **FIFO Buffer**: RMMI data buffering
2. **Data Formatter**: Data packing/unpacking
3. **Mode Selector**: HS/LS mode selection
4. **Output Mux**: Routes to HS or LS processor

### 6.2 Data Flow
```
RMMI TX Interface
    ?
TX FIFO (async)
    ?
32bit ? 16bit (HS) or 8bit (LS)
    ?
HS/LS Processor
    ?
PHY Interface
```

## 7. RX Data Path

### 7.1 Functional Modules
1. **Mode Selector**: HS/LS mode selection
2. **Input Mux**: Routes from HS or LS processor
3. **FIFO Buffer**: RMMI data buffering
4. **SOT/EOT Generator**: Packet boundary detection

### 7.2 Data Flow
```
PHY Interface
    ?
HS/LS Processor
    ?
16bit ? 32bit (HS) or 8bit ? 32bit (LS)
    ?
RX FIFO (async)
    ?
RMMI RX Interface
```

## 8. Clock Domain Cross (CDC) Management

### 8.1 Cross-Clock Domain Paths
- RMMI clock domain ? Internal clock domain
- RMMI clock domain ? HS clock domain
- RMMI clock domain ? LS clock domain
- APB clock domain ? Internal clock domain (config only)

### 8.2 Synchronization Strategy
- **Configuration Signals**: Use two-stage flip-flop synchronization
- **Data Signals**: Use async FIFO
- **Handshake Signals**: Use async handshake protocol

## 9. Reserved Module Interface Design

### 9.1 Analog Calibration Interface
- Reserved configuration register space (0x24-0x7F)
- Reserved control signal interface
- Reserved status feedback interface

### 9.2 Channel Processing Algorithm Interface
- Reserved configuration register space (0x80-0xFB)
- Reserved data channel interface
- Reserved algorithm result interface

## 10. Data Path Summary

### 10.1 Primary Data Path (RMMI)
- **Purpose**: All data communication with UniPro controller
- **Direction**: Bidirectional
- **Clock**: RMMI clock domain
- **Data Width**: 32bit

### 10.2 Configuration Path (APB)
- **Purpose**: Configuration and debugging only
- **Direction**: Bidirectional (register access)
- **Clock**: APB clock domain
- **Data Width**: 32bit
- **Note**: Does NOT handle data traffic
