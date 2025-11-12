# 高性能HASH模块架构设计文档

## 1. 系统需求分析

### 1.1 接口规格
- **数据位宽**: 256bit
- **接口协议**: AXI-Stream
- **处理块大小**: 512bit (每个block需要2个时钟周期接收)
- **系统时钟**: 1GHz
- **目标吞吐率**: 15GB/s

### 1.2 性能分析
- 目标吞吐率: 15GB/s = 15 * 10^9 bytes/s
- 时钟频率: 1GHz = 10^9 cycles/s
- 每个cycle需要处理: 15 bytes = 120 bits
- 256bit接口每个cycle传输: 32 bytes
- 理论最大吞吐率: 32GB/s (256bit @ 1GHz)
- **结论**: 15GB/s的目标吞吐率是可行的，需要约47%的接口利用率

### 1.3 支持的算法
- MD5: 输出128bit
- SHA256: 输出256bit  
- SHA1: 输出160bit

## 2. 系统架构设计

### 2.1 顶层架构
```
┌─────────────────────────────────────────────────────────┐
│                    AXI-Stream Interface                  │
│  (256bit数据位宽, TLAST, TVALID, TREADY, TDATA)         │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Input Buffer & Block Formatter             │
│  - 接收256bit数据流                                      │
│  - 组装512bit blocks                                     │
│  - 处理padding和length字段                               │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Algorithm Selector & Router                 │
│  - 根据配置选择MD5/SHA256/SHA1                           │
│  - 路由数据到对应的算法模块                               │
└─────┬──────────────┬──────────────┬─────────────────────┘
      │              │              │
      ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│   MD5    │  │ SHA256   │  │  SHA1    │
│ Pipeline │  │ Pipeline │  │ Pipeline │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
     └─────────────┴─────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│              Output Buffer & Result Formatter           │
│  - 缓存hash结果                                          │
│  - 通过AXI-Stream输出                                    │
└─────────────────────────────────────────────────────────┘
```

### 2.2 数据流设计
1. **输入阶段**: AXI-Stream接口接收256bit数据，缓存并组装成512bit blocks
2. **处理阶段**: 根据算法选择，将512bit block送入对应的算法pipeline
3. **输出阶段**: 算法完成后，将hash结果通过AXI-Stream输出

### 2.3 关键设计决策
- **Pipeline设计**: 每个算法采用深度pipeline以提高吞吐率
- **双缓冲**: 输入和输出采用双缓冲机制，实现流水线处理
- **算法并行**: 三个算法模块独立，可同时存在（但每次只激活一个）

## 3. 微架构设计

### 3.1 MD5算法微架构

#### 3.1.1 MD5算法特性
- Block size: 512bit
- 轮数: 64轮（4个阶段，每个阶段16轮）
- 每轮处理: 32bit字
- 需要16个32bit字（512bit）作为输入

#### 3.1.2 Pipeline设计
```
Stage 1: 数据准备 (1 cycle)
  - 将512bit block分解为16个32bit字
  - 初始化临时变量

Stage 2-65: 64轮计算 (64 cycles)
  - 每轮执行: F/G/H/I函数 + 加法 + 左旋转
  - 深度pipeline，每cycle完成1轮

Stage 66: 结果更新 (1 cycle)
  - 更新hash状态
  - 准备输出

Total: 66 cycles per block
```

#### 3.1.3 吞吐率评估
- 每个block: 66 cycles
- 每个block数据: 512bit = 64 bytes
- 吞吐率: 64 bytes / 66 cycles = 0.97 bytes/cycle
- @1GHz: 0.97 GB/s (单block)
- **需要16个并行pipeline才能达到15GB/s**

### 3.2 SHA256算法微架构

#### 3.2.1 SHA256算法特性
- Block size: 512bit
- 轮数: 64轮
- 每轮处理: 32bit字
- 需要16个32bit字（512bit）作为输入

#### 3.2.2 Pipeline设计
```
Stage 1: 消息扩展 (1 cycle)
  - 准备W[0..15]

Stage 2-17: 消息扩展继续 (16 cycles)
  - 计算W[16..63]，每cycle计算3个W值（pipeline优化）

Stage 18-81: 64轮主循环 (64 cycles)
  - 每轮执行: Ch/Maj函数 + Σ函数 + 加法
  - 深度pipeline，每cycle完成1轮

Stage 82: 结果更新 (1 cycle)
  - 更新hash状态

Total: 82 cycles per block
```

#### 3.2.3 吞吐率评估
- 每个block: 82 cycles
- 每个block数据: 512bit = 64 bytes
- 吞吐率: 64 bytes / 82 cycles = 0.78 bytes/cycle
- @1GHz: 0.78 GB/s (单block)
- **需要19个并行pipeline才能达到15GB/s**

### 3.3 SHA1算法微架构

#### 3.3.1 SHA1算法特性
- Block size: 512bit
- 轮数: 80轮（4个阶段，每个阶段20轮）
- 每轮处理: 32bit字
- 需要16个32bit字（512bit）作为输入

#### 3.3.2 Pipeline设计
```
Stage 1: 数据准备 (1 cycle)
  - 将512bit block分解为16个32bit字

Stage 2-81: 80轮计算 (80 cycles)
  - 每轮执行: f函数 + 加法 + 左旋转
  - 深度pipeline，每cycle完成1轮

Stage 82: 结果更新 (1 cycle)
  - 更新hash状态

Total: 82 cycles per block
```

#### 3.3.3 吞吐率评估
- 每个block: 82 cycles
- 每个block数据: 512bit = 64 bytes
- 吞吐率: 64 bytes / 82 cycles = 0.78 bytes/cycle
- @1GHz: 0.78 GB/s (单block)
- **需要19个并行pipeline才能达到15GB/s**

## 4. 高性能优化策略

### 4.1 多Pipeline并行
为了达到15GB/s的吞吐率，需要多个pipeline并行处理：
- **MD5**: 16个并行pipeline
- **SHA256**: 19个并行pipeline
- **SHA1**: 19个并行pipeline

### 4.2 简化设计（实际实现）
考虑到设计复杂度，实际实现采用：
- **单Pipeline + 深度优化**: 通过优化关键路径，减少cycle数
- **消息扩展优化**: SHA256/SHA1的消息扩展可以并行计算
- **函数计算优化**: 使用查找表或并行计算单元

### 4.3 实际Cycle数优化目标
- **MD5**: 优化到40-50 cycles/block（通过并行计算）
- **SHA256**: 优化到50-60 cycles/block（消息扩展并行）
- **SHA1**: 优化到50-60 cycles/block（函数并行）

### 4.4 多Block并行处理
- 实现多个block的并行处理pipeline
- 使用round-robin调度分配blocks到不同的pipeline
- 预计需要8-10个并行pipeline来达到15GB/s

## 5. 接口设计

### 5.1 AXI-Stream输入接口
```verilog
input wire [255:0] s_axis_tdata,    // 256bit数据
input wire         s_axis_tvalid,   // 数据有效
output reg         s_axis_tready,   // 接收就绪
input wire         s_axis_tlast,    // 最后一个数据
input wire [31:0]  s_axis_tkeep     // 字节有效掩码
```

### 5.2 AXI-Stream输出接口
```verilog
output reg [255:0] m_axis_tdata,    // 256bit数据（hash结果）
output reg         m_axis_tvalid,   // 数据有效
input wire         m_axis_tready,   // 接收就绪
output reg         m_axis_tlast     // 最后一个数据
```

### 5.3 控制接口
```verilog
input wire [1:0]   algorithm_sel,   // 00: MD5, 01: SHA256, 10: SHA1
input wire         start,           // 开始计算
output reg         ready,           // 模块就绪
output reg         done             // 计算完成
```

## 6. 实现策略

### 6.1 模块划分
1. **axi_stream_if.v**: AXI-Stream接口处理
2. **block_formatter.v**: 512bit block组装和padding
3. **md5_core.v**: MD5算法核心
4. **sha256_core.v**: SHA256算法核心
5. **sha1_core.v**: SHA1算法核心
6. **hash_top.v**: 顶层模块，集成所有子模块

### 6.2 验证策略
- 使用标准测试向量验证每个算法
- 使用AXI-Stream协议验证接口
- 性能测试验证吞吐率
