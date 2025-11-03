# MIPI M-PHY Microarchitecture Design Document

## 1. APB3.0 Configuration Module

### 1.1 Functional Description
- Implements APB3.0 slave interface
- Manages configuration register bank
- Provides register read/write access

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

## 2. M-PHY State Machine

### 2.1 State Definitions
According to M-PHY 5.0 protocol:
- **HIBERN8**: Hibernation state (lowest power consumption)
- **SLEEP**: Sleep state
- **STALL**: Stall state
- **HS-BURST**: High-speed burst transmission
- **LS-BURST**: Low-speed transmission

### 2.2 State Transition Diagram

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

### 2.3 State Transition Conditions
- HIBERN8 ? SLEEP: Wake-up command
- SLEEP ? STALL: Enable command
- STALL ? HS-BURST: HS mode enable + GEAR configuration complete
- STALL ? LS-BURST: LS mode enable
- Any state ? HIBERN8: Disable command

## 3. High-Speed Mode Processor

### 3.1 GEAR Rate Table
| GEAR | Rate (Mbps/lane) | Clock Frequency |
|------|------------------|-----------------|
| 1    | 1458             | ~729 MHz        |
| 2    | 2917             | ~1458 MHz       |
| 3    | 5834             | ~2917 MHz       |
| 4    | 11668            | ~5834 MHz       |
| 5    | 23336            | ~11668 MHz      |

### 3.2 Data Processing Flow
1. **Data Packing**: 32bit user data ? 16bit PHY data
2. **8b/10b Encoding**: Each 8bit data encoded to 10bit symbol
3. **GEAR Adaptation**: Data rate selection based on GEAR
4. **Clock Generation**: TX clock generation based on reference clock

### 3.3 Clock Domain Management
- User clock domain (clk)
- HS reference clock domain (hs_ref_clk)
- TX clock domain (hs_tx_clk)
- RX clock domain (hs_rx_clk)

Use async FIFO for cross-clock domain data transfer.

## 4. Low-Speed Mode Processor

### 4.1 Features
- 8bit data width
- LS-GEAR-A: Standard low-speed
- LS-GEAR-B: Low-speed mode B (optional)

### 4.2 Data Processing
- Direct transmission, no 8b/10b encoding required
- Uses independent low-speed clock domain

## 5. TX Data Path

### 5.1 Functional Modules
1. **FIFO Buffer**: User data buffering
2. **Data Formatter**: Data packing/unpacking
3. **Encoder**: 8b/10b encoding (HS mode only)
4. **Rate Adapter**: GEAR rate adaptation
5. **Output Driver**: Drive to analog PHY

### 5.2 Data Flow
```
32bit User Data
    ?
TX FIFO (async)
    ?
32bit ? 16bit (HS) or 8bit (LS)
    ?
8b/10b Encoder (HS only)
    ?
Gear Rate Adapter
    ?
PHY Interface
```

## 6. RX Data Path

### 6.1 Functional Modules
1. **Input Synchronization**: Data synchronization from PHY
2. **Decoder**: 8b/10b decoding (HS mode only)
3. **Rate Adapter**: GEAR rate adaptation
4. **Data Formatter**: Data unpacking
5. **FIFO Buffer**: User data buffering

### 6.2 Data Flow
```
PHY Interface
    ?
Gear Rate Adapter
    ?
8b/10b Decoder (HS only)
    ?
16bit ? 32bit (HS) or 8bit ? 32bit (LS)
    ?
RX FIFO (async)
    ?
32bit User Data
```

## 7. Clock Domain Cross (CDC) Management

### 7.1 Cross-Clock Domain Paths
- APB clock domain ? HS clock domain
- APB clock domain ? LS clock domain
- HS clock domain ? LS clock domain
- User clock domain ? HS/LS clock domain

### 7.2 Synchronization Strategy
- **Configuration Signals**: Use two-stage flip-flop synchronization
- **Data Signals**: Use async FIFO
- **Handshake Signals**: Use async handshake protocol

## 8. Reserved Module Interface Design

### 8.1 Analog Calibration Interface
- Reserved configuration register space (0x24-0x7F)
- Reserved control signal interface
- Reserved status feedback interface

### 8.2 Channel Processing Algorithm Interface
- Reserved configuration register space (0x80-0xFB)
- Reserved data channel interface
- Reserved algorithm result interface
