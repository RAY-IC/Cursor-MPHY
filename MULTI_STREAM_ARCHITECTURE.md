# 多数据流HASH模块架构设计

## 需求

- **多数据流**: 支持多个独立的数据流并行处理
- **目标吞吐率**: 15 GB/s @ 1GHz
- **数据位宽**: 256bit AXI-Stream
- **Block大小**: 512bit
- **算法**: MD5/SHA256/SHA1

## 架构设计

### 核心思想

**多Pipeline并行架构**:
- 多个独立的hash pipeline，每个处理一个数据流
- Round-robin调度器分配数据流到不同的pipeline
- 每个pipeline独立处理一个完整的数据流（多个blocks）
- 结果收集器按数据流ID排序输出结果

### Pipeline数量计算

#### 单Pipeline吞吐率
- **MD5**: ~1.0-1.4 GB/s（考虑pipeline效率）
- **SHA256**: ~1.0-1.2 GB/s
- **SHA1**: ~0.8-1.1 GB/s

#### 目标吞吐率
- **目标**: 15 GB/s
- **保守估计**: 使用1.0 GB/s/pipeline
- **需要Pipeline数**: 15 / 1.0 = 15个
- **考虑余量**: 使用16个pipeline（与之前设计一致）

### 架构图

```
AXI-Stream Input (256bit)
    ↓
Stream ID Extractor (提取数据流ID)
    ↓
Round-Robin Scheduler
    ├─ Stream 0 → Pipeline 0
    ├─ Stream 1 → Pipeline 1
    ├─ Stream 2 → Pipeline 2
    ├─ ...
    └─ Stream N → Pipeline N
    ↓
16x Hash Pipeline Cores
    ├─ Pipeline 0: Stream 0 (Block 0, 1, 2, ...)
    ├─ Pipeline 1: Stream 1 (Block 0, 1, 2, ...)
    ├─ Pipeline 2: Stream 2 (Block 0, 1, 2, ...)
    ├─ ...
    └─ Pipeline 15: Stream 15 (Block 0, 1, 2, ...)
    ↓
Result Collector (按Stream ID排序)
    ↓
AXI-Stream Output (256bit)
```

## 关键设计点

### 1. 数据流识别

**方案**: 使用AXI-Stream的TID字段标识数据流
- **TID位宽**: 4bit（支持16个数据流）
- **TID=0**: Stream 0
- **TID=1**: Stream 1
- ...
- **TID=15**: Stream 15

### 2. 调度策略

**Round-Robin调度**:
- 新数据流到达时，分配到下一个可用的pipeline
- 每个pipeline处理一个完整的数据流（直到TLAST）
- Pipeline完成后，可以接受新的数据流

### 3. Pipeline状态管理

每个Pipeline需要维护：
- **Stream ID**: 当前处理的数据流ID
- **Hash状态**: 当前数据流的hash状态（h0-h3等）
- **Block计数**: 当前数据流已处理的block数
- **Busy标志**: Pipeline是否正在处理数据流

### 4. 结果收集

**按Stream ID排序**:
- 使用FIFO队列存储每个pipeline的结果
- 按Stream ID顺序输出结果
- 支持乱序完成，顺序输出

## 吞吐率分析

### 理论吞吐率

假设16个pipeline，每个1.0 GB/s:
- **总吞吐率**: 16 × 1.0 = 16 GB/s
- **考虑效率**: 16 × 0.9 = 14.4 GB/s（90%效率）
- **实际可达**: ~14-15 GB/s ✅

### Pipeline利用率

- **理想情况**: 16个数据流同时处理，利用率100%
- **实际情况**: 数据流到达可能不均匀，利用率~90-95%
- **平均吞吐率**: ~13-15 GB/s

## 资源评估（LUT）

### 单Pipeline资源
- **MD5 Pipeline**: ~10,000 LUT
- **SHA256 Pipeline**: ~15,000 LUT
- **SHA1 Pipeline**: ~13,000 LUT
- **Pipeline控制**: ~1,000 LUT

### 16-Pipeline总资源

| 模块 | MD5 (LUT) | SHA256 (LUT) | SHA1 (LUT) |
|------|-----------|--------------|------------|
| 16x Hash核心 | 160,000 | 240,000 | 208,000 |
| 调度器 | ~5,000 | ~5,000 | ~5,000 |
| 结果收集器 | ~8,000 | ~8,000 | ~8,000 |
| AXI接口 | ~3,000 | ~3,000 | ~3,000 |
| Block格式化 | ~2,000 | ~2,000 | ~2,000 |
| **总计** | **~178,000** | **~258,000** | **~226,000** |

## 实现模块

### 1. stream_scheduler.v
- **功能**: 多数据流调度器
- **特点**: 
  - Round-robin分配数据流到pipeline
  - 维护每个pipeline的状态（busy/idle）
  - 支持数据流完成后的pipeline释放

### 2. stream_pipeline_core.v
- **功能**: 单个数据流的pipeline核心
- **特点**: 
  - 处理一个完整的数据流（多个blocks）
  - 维护hash状态（跨blocks）
  - 支持block级流水线

### 3. result_collector_multi_stream.v
- **功能**: 多数据流结果收集器
- **特点**: 
  - 按Stream ID排序输出
  - 支持乱序完成
  - FIFO缓冲结果

### 4. hash_top_multi_stream.v
- **功能**: 多数据流顶层模块
- **特点**: 
  - 集成16个pipeline
  - AXI-Stream接口（支持TID）
  - 算法选择（MD5/SHA256/SHA1）

## 性能目标

### 吞吐率
- **目标**: 15 GB/s ✅
- **理论**: 16 GB/s
- **实际**: ~14-15 GB/s

### 延迟
- **单数据流延迟**: 与单pipeline相同
- **多数据流**: 并行处理，互不影响

## 总结

### 优势
✅ **高吞吐率**: 16个pipeline并行，可达15GB/s
✅ **可扩展**: 可以增加pipeline数量进一步提高吞吐率
✅ **灵活性**: 支持多个独立数据流同时处理

### 资源需求
- **LUT**: ~178K-258K（取决于算法）
- **适合**: 大型FPGA（如Xilinx UltraScale+）

### 适用场景
- **多数据流**: 多个独立的数据流需要hash
- **高吞吐率**: 需要15GB/s以上的吞吐率
- **并行处理**: 数据流之间相互独立
