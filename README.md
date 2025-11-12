# 高性能CRC加速引擎设计

## 项目概述

本项目实现了一个高性能CRC（循环冗余校验）加速引擎，支持CRC32、CRC32C和CRC64三种CRC算法，采用AXI-Stream接口，数据位宽256bit，目标吞吐率10GB/s，工作时钟1.2GHz。

## 设计规格

- **数据位宽**: 256bit
- **接口协议**: AXI-Stream
- **支持的CRC类型**: 
  - CRC32 (多项式: 0x04C11DB7, IEEE 802.3)
  - CRC32C (多项式: 0x1EDC6F41, Castagnoli)
  - CRC64 (多项式: 0x42F0E1EBA9EA3693, ECMA-182)
- **工作模式**: On-the-fly计算（流水线处理）
- **系统时钟**: 1.2GHz
- **目标吞吐率**: 10GB/s

## 目录结构

```
.
├── docs/                    # 设计文档
│   ├── architecture.md     # 架构设计文档
│   └── microarchitecture.md # 微架构设计文档
├── rtl/                     # RTL源代码
│   ├── crc_accelerator_top.v      # 顶层模块
│   ├── crc_engine.v               # CRC计算引擎
│   ├── axi_stream_if.v            # AXI-Stream接口模块
│   ├── crc32_parallel.v           # CRC32并行计算单元（32bit）
│   ├── crc32c_parallel.v          # CRC32C并行计算单元（32bit）
│   ├── crc64_parallel.v           # CRC64并行计算单元（64bit）
│   ├── crc32_parallel_256.v       # CRC32并行计算单元（256bit）
│   ├── crc32c_parallel_256.v      # CRC32C并行计算单元（256bit）
│   └── crc64_parallel_256.v       # CRC64并行计算单元（256bit）
├── tb/                      # 验证testbench
│   ├── crc_accelerator_tb.v      # 主testbench
│   └── crc_reference.v           # 参考CRC计算函数
├── scripts/                 # 脚本文件
│   └── run_sim.sh           # 仿真脚本
└── README.md                # 本文件
```

## 架构设计

### 整体架构

```
┌─────────────────────────────────────────┐
│      CRC Accelerator Top                │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐   │
│  │ AXI-Stream   │  │   Control    │   │
│  │   Interface  │◄─┤    Logic     │   │
│  └──────┬───────┘  └──────┬───────┘   │
│         │                 │            │
│         │ 256-bit data    │ CRC type   │
│         ▼                 │            │
│  ┌──────────────────────────────┐      │
│  │   CRC Calculation Engine     │      │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ │      │
│  │  │CRC32 │ │CRC32C│ │CRC64 │ │      │
│  │  └──────┘ └──────┘ └──────┘ │      │
│  └──────────────────────────────┘      │
│         │                               │
│         │ CRC result                    │
│         ▼                               │
│  ┌──────────────┐                       │
│  │ Result Buffer│                       │
│  └──────────────┘                       │
└─────────────────────────────────────────┘
```

### 接口定义

#### AXI-Stream Slave接口（输入）
- `s_axis_tdata[255:0]`: 256-bit数据
- `s_axis_tvalid`: 数据有效信号
- `s_axis_tready`: 接收就绪信号
- `s_axis_tlast`: 数据包结束标志
- `s_axis_tkeep[31:0]`: 字节有效掩码

#### AXI-Stream Master接口（输出）
- `m_axis_tdata[63:0]`: CRC结果
- `m_axis_tvalid`: 结果有效信号
- `m_axis_tready`: 下游就绪信号
- `m_axis_tlast`: 结果包结束标志

#### 控制接口
- `crc_type[1:0]`: CRC类型选择（00=CRC32, 01=CRC32C, 10=CRC64）
- `crc_init[63:0]`: CRC初始值
- `crc_enable`: CRC计算使能
- `crc_reset`: CRC复位

## 性能指标

### 吞吐率分析
- **理论最大吞吐率**: 256bit × 1.2GHz = 307.2 Gbps = 38.4 GB/s
- **目标吞吐率**: 10GB/s
- **效率要求**: ~26%（考虑流水线开销和AXI握手）

### 延迟
- **流水线延迟**: 3-4个时钟周期
- **端到端延迟**: < 5ns（在1.2GHz下）

### 资源估算
- **LUT**: ~5000-8000
- **FF**: ~3000-5000
- **BRAM**: 0-20块（取决于实现方式）

## 使用方法

### 仿真

使用提供的仿真脚本运行testbench：

```bash
cd scripts
./run_sim.sh
```

或者手动指定仿真工具：

```bash
SIM_TOOL=vcs ./run_sim.sh
SIM_TOOL=xcelium ./run_sim.sh
SIM_TOOL=questa ./run_sim.sh
SIM_TOOL=iverilog ./run_sim.sh
```

### 综合

使用综合工具（如Design Compiler, Genus等）进行综合：

```tcl
# 示例综合脚本
read_verilog rtl/*.v
set_top crc_accelerator_top
create_clock -period 0.833 -name clk [get_ports clk]
set_clock_uncertainty 0.1 [get_clocks clk]
set_input_delay 0.3 -clock clk [all_inputs]
set_output_delay 0.3 -clock clk [all_outputs]
compile_ultra
```

## 测试用例

Testbench包含以下测试用例：

1. **CRC32功能测试**: 使用标准测试向量"123456789"验证CRC32计算
2. **CRC32C功能测试**: 使用标准测试向量"123456789"验证CRC32C计算
3. **多包处理测试**: 验证连续数据包的处理能力
4. **吞吐率测试**: 发送100个数据包测试吞吐率

## 设计特点

1. **流水线设计**: 采用多级流水线实现On-the-fly计算，无需预先存储整个数据块
2. **并行处理**: 充分利用256bit数据位宽，实现高吞吐率
3. **低延迟**: 优化的流水线设计，最小化处理延迟
4. **资源复用**: 共享部分计算资源，减少硬件开销

## 注意事项

1. **CRC初始值**: 默认使用0xFFFFFFFF（CRC32/CRC32C）或0xFFFFFFFFFFFFFFFF（CRC64）
2. **数据对齐**: 数据应按照小端序（little-endian）排列
3. **tkeep信号**: 当前实现中tkeep信号已连接但未完全使用，可根据需要扩展
4. **时钟域**: 所有模块工作在单时钟域（1.2GHz）

## 未来改进

1. **支持更多CRC类型**: 可扩展支持CRC16、CRC8等
2. **优化关键路径**: 进一步优化CRC计算逻辑以支持更高频率
3. **添加FIFO缓冲**: 在AXI接口添加FIFO以更好地处理背压
4. **支持字节使能**: 完善tkeep信号的处理逻辑

## 作者

数字IC设计工程师

## 许可证

本项目仅供学习和研究使用。
