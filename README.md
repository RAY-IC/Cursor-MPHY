# AES256-CTR Stream Cipher Engine

## Project Overview

This project implements a new, independent AES256-CTR stream cipher engine that strictly follows the NIST SP 800-38A standard, supports Key-on-the-fly features, and is optimized for high-performance throughput.

## Key Features

- ? **Algorithm**: AES256-CTR, following NIST SP 800-38A
- ? **Key Length**: Fixed 256-bit
- ? **Key-on-the-fly**: Support dynamic key loading per data packet
- ? **High Performance**: Encryption >=7GB/s, Decryption >=15GB/s
- ? **Low Latency**: Average latency <70us for 512KB data blocks
- ? **Internal Self-Test**: Support encrypt-then-decrypt loopback test mode
- ? **Standard Interfaces**: AXI4-Stream data interface + APB control interface

## Project Structure

```
/workspace/
??? rtl/                    # RTL design files
?   ??? aes256_ctr_top.sv   # Top-level module
?   ??? aes256_core.sv      # AES256 core engine
?   ??? ctr_mode_engine.sv  # CTR mode controller
?   ??? key_manager.sv       # Key manager
?   ??? axi_stream_interface.sv  # AXI4-Stream interface
?   ??? apb_interface.sv    # APB control interface
??? tb/                     # Testbench
?   ??? aes256_ctr_tb.sv    # Comprehensive testbench
??? doc/                    # Documentation
?   ??? microarchitecture_design.md  # Microarchitecture design document
?   ??? synthesis_timing_analysis.md  # Synthesis and timing analysis report template
??? scripts/                # Scripts
?   ??? synthesis.tcl       # Synthesis script
??? README.md               # This file
```

## Quick Start

### 1. Simulation Environment Setup

Ensure you have a SystemVerilog simulator (such as VCS, Questa, or open-source tools):

```bash
# Compile (example using VCS)
vcs -sverilog -full64 \
    rtl/aes256_core.sv \
    rtl/ctr_mode_engine.sv \
    rtl/key_manager.sv \
    rtl/axi_stream_interface.sv \
    rtl/apb_interface.sv \
    rtl/aes256_ctr_top.sv \
    tb/aes256_ctr_tb.sv \
    -top aes256_ctr_tb

# Run simulation
./simv
```

### 2. Synthesis Flow

Use the provided synthesis script:

```bash
# Set up synthesis tool environment (according to your tool)
# Example for Synopsys Design Compiler:
source /path/to/synopsys/setup.sh

# Run synthesis
dc_shell -f scripts/synthesis.tcl
```

## Interface Specifications

### AXI4-Stream Interface

**Input (Slave)**:
- `s_axis_tdata[511:0]`: 512-bit data
- `s_axis_tuser[383:0]`: `{KEY[255:0], IV[127:0], CTRL[1:0]}`
  - `CTRL[0]`: SOF (Start of Frame) / IV valid
  - `CTRL[1]`: KEY_VALID (key valid flag)

**Output (Master)**:
- `m_axis_tdata[511:0]`: 512-bit encrypted/decrypted result

### APB Control Interface

**Register Map**:
- `0x000`: Control Register
  - `[0]`: Enable
  - `[1]`: Encrypt mode (1=encrypt, 0=decrypt)
  - `[2]`: Loopback mode
  - `[3]`: Key load via TUSER
- `0x004`: Status Register (Read-only)
- `0x008`: Byte Count (Read-only)
- `0x00C`: Packet Count (Read-only)

## Test Description

The testbench includes the following tests:

1. **Basic Encryption Test**: Verify basic encryption functionality
2. **Key-on-the-fly Test**: Verify dynamic key loading
3. **Loopback Test**: Verify internal self-test mode
4. **Multiple IV Test**: Verify independent IV per packet
5. **Decryption Test**: Verify decryption functionality

Running simulation will automatically execute all test cases.

## Performance Metrics

### Design Targets

- **Encryption Throughput**: >= 7 GB/s
- **Decryption Throughput**: >= 15 GB/s
- **Latency**: 512KB data block < 70us

### Implementation Features

- **Data Width**: 512-bit (4 x 128-bit blocks)
- **Parallel AES Cores**: 4 cores
- **Pipeline Depth**: Deep pipeline design

**Note**: Actual performance depends on post-synthesis timing results. Please refer to synthesis reports.

## Design Documentation

Detailed microarchitecture design document can be found at:
- `doc/microarchitecture_design.md`

## Verification Status

- ? RTL design complete
- ? Testbench complete
- ? Synthesis and timing analysis (to be executed)
- ? Post-synthesis simulation (to be executed)

## Notes

1. **S-box Implementation**: Currently uses lookup table. Can choose LUT or BRAM based on target technology
2. **Key Expansion**: Uses combinational logic. Can add pipeline based on timing requirements
3. **Side-Channel Protection**: Current design does not include side-channel protection. Production use requires additions
4. **Synthesis Constraints**: Need to adjust timing constraints in synthesis script based on actual technology library

## License

[Specify license according to your requirements]

## Contact

[Your contact information]

## Changelog

- **v1.0** (2024): Initial version
  - Complete core RTL design
  - Complete testbench
  - Complete design documentation
