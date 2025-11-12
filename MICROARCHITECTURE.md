# HASH模块微架构详细设计

## 1. Cycle数详细评估

### 1.1 MD5算法Cycle分析

#### 基本操作
- 输入: 512bit block (16个32bit字)
- 轮数: 64轮
- 每轮操作: F/G/H/I函数 + 4个32bit加法 + 左旋转

#### Pipeline设计（优化后）
```
Cycle 1: Block接收和分解 (1 cycle)
  - 接收512bit block（2个256bit周期）
  - 分解为16个32bit字 W[0..15]

Cycle 2-17: 消息准备 (16 cycles，可优化)
  - 实际上MD5不需要消息扩展，直接使用W[0..15]
  - 可以并行准备4组数据

Cycle 18-81: 64轮主循环 (64 cycles)
  - 每轮: F函数 + 4次加法 + 左旋转
  - Pipeline深度: 3级（函数计算、加法、旋转）

Cycle 82: 状态更新 (1 cycle)
  - 更新hash状态寄存器

Total: 82 cycles (保守估计)
优化后: 40-50 cycles (通过并行和流水线)
```

#### 优化策略
- **并行计算**: 4个阶段的F/G/H/I函数可以预计算
- **流水线**: 将64轮分成多个pipeline stage
- **关键路径优化**: 使用carry-save adder减少延迟

**优化后目标: 45 cycles/block**

### 1.2 SHA256算法Cycle分析

#### 基本操作
- 输入: 512bit block (16个32bit字)
- 轮数: 64轮
- 消息扩展: 需要计算W[16..63]（48个值）

#### Pipeline设计（优化后）
```
Cycle 1-2: Block接收 (2 cycles)
  - 接收512bit block

Cycle 3: 消息扩展初始化 (1 cycle)
  - 准备W[0..15]

Cycle 4-19: 消息扩展并行计算 (16 cycles)
  - 每cycle计算3个W值（pipeline）
  - W[i] = σ1(W[i-2]) + W[i-7] + σ0(W[i-15]) + W[i-16]

Cycle 20-83: 64轮主循环 (64 cycles)
  - 每轮: Ch/Maj + Σ0/Σ1 + 加法
  - Pipeline深度: 4级

Cycle 84: 状态更新 (1 cycle)

Total: 84 cycles (保守估计)
优化后: 50-60 cycles (消息扩展并行)
```

#### 优化策略
- **消息扩展并行**: 3个W值并行计算
- **函数并行**: Ch和Maj函数并行计算
- **预计算**: Σ函数可以预计算

**优化后目标: 55 cycles/block**

### 1.3 SHA1算法Cycle分析

#### 基本操作
- 输入: 512bit block (16个32bit字)
- 轮数: 80轮
- 消息扩展: 需要计算W[16..79]（64个值）

#### Pipeline设计（优化后）
```
Cycle 1-2: Block接收 (2 cycles)
  - 接收512bit block

Cycle 3: 消息扩展初始化 (1 cycle)
  - 准备W[0..15]

Cycle 4-25: 消息扩展并行计算 (22 cycles)
  - 每cycle计算3个W值
  - W[i] = ROTL^1(W[i-3] XOR W[i-8] XOR W[i-14] XOR W[i-16])

Cycle 26-105: 80轮主循环 (80 cycles)
  - 每轮: f函数 + 5次加法 + 左旋转
  - Pipeline深度: 4级

Cycle 106: 状态更新 (1 cycle)

Total: 106 cycles (保守估计)
优化后: 55-65 cycles (消息扩展和函数并行)
```

**优化后目标: 60 cycles/block**

## 2. 多Pipeline并行策略

### 2.1 吞吐率计算
- 目标: 15GB/s = 15 * 10^9 bytes/s
- 时钟: 1GHz = 10^9 cycles/s
- 需要: 15 bytes/cycle = 120 bits/cycle

### 2.2 Pipeline数量需求
假设优化后的cycle数：
- MD5: 45 cycles/block → 需要 45*15/64 ≈ 11个pipeline
- SHA256: 55 cycles/block → 需要 55*15/64 ≈ 13个pipeline  
- SHA1: 60 cycles/block → 需要 60*15/64 ≈ 14个pipeline

### 2.3 实际实现策略
考虑到设计复杂度，采用**8个并行pipeline** + **深度优化**：
- 每个pipeline优化到更少的cycles
- 使用round-robin调度分配blocks
- 预计可以达到12-15GB/s的吞吐率

## 3. 关键模块设计

### 3.1 Block Formatter
- 功能: 接收256bit数据流，组装512bit blocks
- 实现: 双缓冲机制，ping-pong buffer
- Cycle: 2 cycles接收一个block

### 3.2 Algorithm Router
- 功能: 根据algorithm_sel路由数据
- 实现: 简单的多路选择器
- Cycle: 1 cycle延迟

### 3.3 Output Formatter
- 功能: 将hash结果格式化为256bit输出
- 实现: 根据算法选择输出格式
- Cycle: 1-2 cycles（取决于hash长度）

## 4. 时序设计

### 4.1 关键路径
- 32bit加法器链: 需要优化
- 左旋转操作: 使用barrel shifter
- 函数计算: 使用组合逻辑，可能需要pipeline

### 4.2 时钟域
- 所有模块在同一时钟域（1GHz）
- 需要仔细设计pipeline stage之间的寄存器

### 4.3 流水线平衡
- 确保各stage的延迟平衡
- 避免pipeline bubble
