# 最终正确的HASH模块架构设计

## 需求确认

1. **单个数据流**: 顺序处理整个数据流
2. **15GB/s是目标值**: 尽可能接近，但不强制要求

## 正确的架构

### 核心思想
- **Block级流水线**: 多个block可以在pipeline的不同stage同时处理
- **状态传递**: 每个block处理完成后，hash状态传递给下一个block
- **深度Pipeline**: 单个hash核心内部深度pipeline，支持block流水线

### 架构图

```
AXI-Stream Input (256bit)
    ↓
Block Formatter (组装512bit blocks)
    ↓
Block FIFO (缓存blocks，支持流水线)
    ↓
Deep Pipeline Hash Core
    ├─ Block 1: Stage 1 (Round 0-7)
    ├─ Block 2: Stage 2 (Round 8-15)  ← Block 1
    ├─ Block 3: Stage 3 (Round 16-23) ← Block 2
    └─ Block 4: Stage 4 (Round 24-31) ← Block 3
    (多个blocks在不同stage同时处理)
    ↓
Hash State Update (顺序更新)
    ↓
AXI-Stream Output (最终hash结果)
```

## 实现方案

### 1. Block Pipeline设计

#### MD5 Pipeline
- **Pipeline深度**: 4个block可以同时在pipeline中
- **每个block**: 64轮，每cycle处理1轮
- **吞吐率**: 当pipeline填满后，每64 cycles完成一个block
- **实际吞吐率**: ~1 GB/s（考虑pipeline填充和排空）

#### 优化策略
- **多block并行处理**: 4个block同时在不同stage处理
- **Pipeline填充**: 前4个block填充pipeline
- **Pipeline排空**: 最后4个block排空pipeline
- **大数据流**: 当block数量 >> 4时，吞吐率接近理论值

### 2. 吞吐率分析

#### 理论分析
- **Pipeline深度**: 4 blocks
- **每个block处理时间**: 64 cycles
- **Pipeline填充时间**: 4 cycles（4个block依次进入）
- **Pipeline排空时间**: 64 cycles（最后一个block完成）

#### 大数据流吞吐率
假设N个blocks，N >> 4:
- **总时间**: 4 + 64 + (N-4)×1 = N + 64 cycles
- **总数据**: N × 64 bytes
- **吞吐率**: (N × 64) / (N + 64) bytes/cycle
- **当N很大时**: ≈ 64 bytes/cycle = 64 GB/s（理论）

#### 实际吞吐率
考虑实际开销：
- **Pipeline效率**: ~90-95%
- **实际吞吐率**: ~1-1.5 GB/s（受限于算法cycle数）

### 3. 无法达到15GB/s的原因

#### 算法限制
- **MD5**: 每个block需要64轮，每轮1 cycle = 64 cycles/block
- **SHA256**: 每个block需要64轮 = 64 cycles/block
- **SHA1**: 每个block需要80轮 = 80 cycles/block

#### 理论最大吞吐率
- **MD5**: 64 bytes / 64 cycles = 1 byte/cycle = 1 GB/s @ 1GHz
- **SHA256**: 64 bytes / 64 cycles = 1 GB/s @ 1GHz
- **SHA1**: 64 bytes / 80 cycles = 0.8 GB/s @ 1GHz

#### 15GB/s的要求
- **需要**: 15 bytes/cycle
- **每个block**: 64 bytes
- **需要**: 64 / 15 ≈ 4.3 cycles/block
- **实际**: 64-80 cycles/block

**结论**: 单个数据流的hash算法无法达到15GB/s（算法本身的限制）

## 实际可达的吞吐率

### 优化后的吞吐率
- **MD5**: ~1.0-1.4 GB/s
- **SHA256**: ~1.0-1.2 GB/s
- **SHA1**: ~0.8-1.1 GB/s

### 进一步优化空间
1. **减少cycle数**: 通过并行计算减少每轮的cycle数（有限）
2. **增加pipeline深度**: 可以隐藏部分延迟，但受限于算法
3. **ASIC优化**: 使用ASIC级别的优化技术

## 资源评估

### 单Pipeline版本（Block流水线）

| 模块 | MD5 (LUT) | SHA256 (LUT) | SHA1 (LUT) |
|------|-----------|--------------|------------|
| Hash核心（block pipeline） | ~10,000 | ~15,000 | ~13,000 |
| Block FIFO | ~2,000 | ~2,000 | ~2,000 |
| AXI接口 | ~2,000 | ~2,000 | ~2,000 |
| Block格式化 | ~1,300 | ~1,300 | ~1,300 |
| **总计** | **~15,300** | **~20,300** | **~18,300** |

## 总结

### 架构特点
1. ✅ **正确**: Block级流水线，符合hash算法特性
2. ✅ **高效**: 多个block可以同时处理
3. ✅ **资源合理**: ~15-20K LUT

### 吞吐率
- **实际可达**: ~1-1.5 GB/s
- **15GB/s**: 无法达到（算法限制）
- **目标值**: 尽可能优化，但受限于算法本身

### 建议
1. **接受现实**: 单个数据流的hash算法吞吐率受限于算法本身
2. **优化实现**: 通过block流水线尽可能提高吞吐率
3. **重新评估**: 如果15GB/s是硬性要求，可能需要考虑其他方案
