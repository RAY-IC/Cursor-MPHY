# 性能分析和Cycle数评估

## 1. 各算法处理一个Block的Cycle数评估

### 1.1 MD5算法

#### 理论分析
- **Block大小**: 512bit
- **轮数**: 64轮
- **每轮操作**: F/G/H/I函数 + 4次32bit加法 + 左旋转

#### Cycle数分解
1. **Block接收**: 2 cycles (256bit × 2 = 512bit)
2. **数据准备**: 1 cycle (分解为16个32bit字)
3. **64轮主循环**: 64 cycles (每轮1 cycle，深度pipeline)
4. **状态更新**: 1 cycle

**总计**: 68 cycles/block (保守估计)

#### 优化后Cycle数
通过以下优化可以降低到 **45-50 cycles/block**:
- 并行计算F/G/H/I函数
- 使用carry-save adder减少加法延迟
- 优化关键路径

**优化目标**: **45 cycles/block**

### 1.2 SHA256算法

#### 理论分析
- **Block大小**: 512bit
- **轮数**: 64轮
- **消息扩展**: 需要计算W[16..63]（48个值）

#### Cycle数分解
1. **Block接收**: 2 cycles
2. **消息扩展初始化**: 1 cycle (W[0..15])
3. **消息扩展计算**: 16 cycles (每cycle计算3个W值，pipeline)
4. **64轮主循环**: 64 cycles
5. **状态更新**: 1 cycle

**总计**: 84 cycles/block (保守估计)

#### 优化后Cycle数
通过消息扩展并行和函数并行，可以降低到 **50-55 cycles/block**:
- 消息扩展并行计算（3个W值/cycle）
- Ch和Maj函数并行
- Σ函数预计算

**优化目标**: **55 cycles/block**

### 1.3 SHA1算法

#### 理论分析
- **Block大小**: 512bit
- **轮数**: 80轮
- **消息扩展**: 需要计算W[16..79]（64个值）

#### Cycle数分解
1. **Block接收**: 2 cycles
2. **消息扩展初始化**: 1 cycle (W[0..15])
3. **消息扩展计算**: 22 cycles (每cycle计算3个W值)
4. **80轮主循环**: 80 cycles
5. **状态更新**: 1 cycle

**总计**: 106 cycles/block (保守估计)

#### 优化后Cycle数
通过优化可以降低到 **55-60 cycles/block**:
- 消息扩展并行
- f函数并行计算
- 关键路径优化

**优化目标**: **60 cycles/block**

## 2. 吞吐率分析

### 2.1 单Pipeline吞吐率

假设优化后的cycle数：
- **MD5**: 45 cycles/block
- **SHA256**: 55 cycles/block
- **SHA1**: 60 cycles/block

每个block = 512bit = 64 bytes

单Pipeline吞吐率：
- **MD5**: 64 bytes / 45 cycles = 1.42 bytes/cycle
- **SHA256**: 64 bytes / 55 cycles = 1.16 bytes/cycle
- **SHA1**: 64 bytes / 60 cycles = 1.07 bytes/cycle

@1GHz时钟：
- **MD5**: 1.42 GB/s
- **SHA256**: 1.16 GB/s
- **SHA1**: 1.07 GB/s

### 2.2 达到15GB/s所需的Pipeline数量

目标吞吐率: 15 GB/s = 15 bytes/cycle @ 1GHz

所需Pipeline数量：
- **MD5**: 15 / 1.42 ≈ **11个pipeline**
- **SHA256**: 15 / 1.16 ≈ **13个pipeline**
- **SHA1**: 15 / 1.07 ≈ **14个pipeline**

### 2.3 实际实现策略

考虑到设计复杂度，建议采用：

1. **8个并行Pipeline** + **深度优化**
   - 每个pipeline进一步优化cycle数
   - 使用round-robin调度
   - 预计可达到 **10-12 GB/s**

2. **16个并行Pipeline**（更激进）
   - 可以达到或超过15GB/s
   - 但设计复杂度显著增加

3. **混合策略**
   - 关键路径使用更多pipeline
   - 非关键路径共享资源

## 3. 关键路径分析

### 3.1 MD5关键路径
- **32bit加法链**: 需要3级pipeline
- **F/G/H/I函数**: 组合逻辑，延迟较小
- **左旋转**: 使用barrel shifter，1 cycle

**关键路径延迟**: 约0.8ns @ 1GHz (需要pipeline)

### 3.2 SHA256关键路径
- **消息扩展**: σ函数 + 3次加法，需要2级pipeline
- **主循环**: Ch/Maj + Σ + 加法，需要3级pipeline
- **32bit加法**: 需要carry-save优化

**关键路径延迟**: 约0.9ns @ 1GHz

### 3.3 SHA1关键路径
- **消息扩展**: 4次XOR + 左旋转，1 cycle
- **主循环**: f函数 + 5次加法 + 左旋转，需要3级pipeline

**关键路径延迟**: 约0.85ns @ 1GHz

## 4. 资源估算

### 4.1 单Pipeline资源
- **寄存器**: ~2000个
- **LUT**: ~3000个
- **BRAM**: 0个（使用寄存器实现）

### 4.2 8 Pipeline资源
- **寄存器**: ~16,000个
- **LUT**: ~24,000个
- **BRAM**: 0个

### 4.3 16 Pipeline资源
- **寄存器**: ~32,000个
- **LUT**: ~48,000个
- **BRAM**: 0个

## 5. 性能优化建议

### 5.1 架构级优化
1. **多Pipeline并行**: 8-16个pipeline
2. **双缓冲**: 输入/输出双缓冲，隐藏延迟
3. **预取**: 提前准备下一个block

### 5.2 算法级优化
1. **消息扩展并行**: SHA256/SHA1的消息扩展并行计算
2. **函数并行**: Ch/Maj/f函数并行计算
3. **预计算**: 常数和函数表预计算

### 5.3 实现级优化
1. **Carry-save adder**: 减少加法延迟
2. **Barrel shifter**: 快速左旋转
3. **Pipeline平衡**: 确保各stage延迟平衡

## 6. 总结

| 算法 | 优化后Cycle数 | 单Pipeline吞吐率 | 达到15GB/s所需Pipeline |
|------|--------------|------------------|----------------------|
| MD5  | 45 cycles    | 1.42 GB/s        | 11个                 |
| SHA256 | 55 cycles  | 1.16 GB/s        | 13个                 |
| SHA1 | 60 cycles    | 1.07 GB/s        | 14个                 |

**推荐方案**: 实现8个并行pipeline，通过深度优化可以达到10-12GB/s的吞吐率。如果需要达到15GB/s，建议实现12-16个并行pipeline。
