# 高性能HASH模块设计

## 项目概述

本项目实现了一个支持MD5、SHA256和SHA1算法的高性能HASH模块，采用AXI-Stream接口，数据位宽256bit，目标吞吐率15GB/s @ 1GHz时钟。

## 文件结构

```
/workspace/
├── ARCHITECTURE.md          # 系统架构设计文档
├── MICROARCHITECTURE.md     # 微架构详细设计文档
├── PERFORMANCE_ANALYSIS.md  # 性能分析和Cycle数评估
├── README.md                # 本文件
├── axi_stream_if.v         # AXI-Stream接口模块
├── block_formatter.v        # Block格式化模块（padding处理）
├── md5_core.v              # MD5算法核心模块
├── sha256_core.v           # SHA256算法核心模块
├── sha1_core.v             # SHA1算法核心模块
├── hash_top.v              # 顶层模块，集成所有子模块
└── tb_hash_top.v           # 验证testbench
```

## 设计规格

### 接口规格
- **数据位宽**: 256bit
- **接口协议**: AXI-Stream
- **处理块大小**: 512bit
- **系统时钟**: 1GHz
- **目标吞吐率**: 15GB/s

### 支持的算法
- **MD5**: 输出128bit hash值
- **SHA256**: 输出256bit hash值
- **SHA1**: 输出160bit hash值

## 架构设计

### 系统架构
1. **AXI-Stream接口层**: 处理256bit数据流的输入/输出
2. **Block格式化层**: 将数据组装成512bit blocks，处理padding
3. **算法路由层**: 根据配置选择MD5/SHA256/SHA1算法
4. **算法核心层**: 实现各hash算法的计算逻辑
5. **结果输出层**: 格式化hash结果并通过AXI-Stream输出

### 性能指标

| 算法 | 优化后Cycle数 | 单Pipeline吞吐率 | 达到15GB/s所需Pipeline |
|------|--------------|------------------|----------------------|
| MD5  | 45 cycles    | 1.42 GB/s        | 11个                 |
| SHA256 | 55 cycles  | 1.16 GB/s        | 13个                 |
| SHA1 | 60 cycles    | 1.07 GB/s        | 14个                 |

**当前实现**: 单pipeline版本，作为基础实现。如需达到15GB/s，需要实现8-16个并行pipeline。

## 使用方法

### 仿真

使用ModelSim/QuestaSim或其他Verilog仿真器：

```bash
# 编译所有模块
vlog axi_stream_if.v
vlog block_formatter.v
vlog md5_core.v
vlog sha256_core.v
vlog sha1_core.v
vlog hash_top.v
vlog tb_hash_top.v

# 运行仿真
vsim -c tb_hash_top -do "run -all"
```

### 接口说明

#### 输入接口（AXI-Stream Slave）
- `s_axis_tdata[255:0]`: 256bit输入数据
- `s_axis_tvalid`: 数据有效信号
- `s_axis_tready`: 接收就绪信号（输出）
- `s_axis_tlast`: 最后一个数据标志
- `s_axis_tkeep[31:0]`: 字节有效掩码

#### 输出接口（AXI-Stream Master）
- `m_axis_tdata[255:0]`: 256bit输出数据（hash结果）
- `m_axis_tvalid`: 数据有效信号（输出）
- `m_axis_tready`: 接收就绪信号（输入）
- `m_axis_tlast`: 最后一个数据标志（输出）

#### 控制接口
- `algorithm_sel[1:0]`: 算法选择
  - `00`: MD5
  - `01`: SHA256
  - `10`: SHA1
- `start`: 开始计算信号
- `ready`: 模块就绪信号（输出）
- `done`: 计算完成信号（输出）

## 设计特点

### 1. 模块化设计
- 各算法独立实现，便于维护和扩展
- 清晰的接口定义，便于集成

### 2. Pipeline优化
- 各算法采用深度pipeline设计
- 关键路径优化，减少cycle数

### 3. AXI-Stream标准接口
- 符合AXI-Stream协议标准
- 便于与其他IP核集成

### 4. 可扩展性
- 当前为单pipeline实现
- 可扩展为多pipeline并行实现以达到更高吞吐率

## 验证

Testbench包含以下测试用例：
1. MD5空字符串测试
2. MD5 "abc"测试
3. SHA256空字符串测试
4. SHA256 "abc"测试
5. SHA1空字符串测试
6. SHA1 "abc"测试

所有测试使用标准测试向量进行验证。

## 性能优化建议

### 达到15GB/s的优化方案

1. **多Pipeline并行**
   - 实现8-16个并行pipeline
   - 使用round-robin调度分配blocks

2. **深度优化**
   - 消息扩展并行计算
   - 函数并行计算
   - 关键路径优化

3. **双缓冲机制**
   - 输入/输出双缓冲
   - 隐藏处理延迟

4. **预取机制**
   - 提前准备下一个block
   - 减少等待时间

## 注意事项

1. **Padding处理**: 当前实现简化了padding逻辑，实际应用中需要根据实际数据长度正确计算padding
2. **多Block处理**: 当前实现主要针对单block处理，多block消息需要正确处理中间状态
3. **时序约束**: 1GHz时钟需要严格的时序约束，建议使用FPGA或ASIC实现时进行时序分析
4. **资源使用**: 多pipeline实现会显著增加资源使用，需要权衡性能和资源

## 作者

数字IC设计工程师

## 版本历史

- v1.0: 初始版本，单pipeline实现，支持MD5/SHA256/SHA1
