# 多Pipeline并行架构设计文档

## 1. 设计目标

实现15GB/s吞吐率的高性能HASH模块，采用多pipeline并行架构。

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│              AXI-Stream Input Interface                  │
│              (256bit, 接收数据流)                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│           Block Formatter & Buffer Manager               │
│           - 组装512bit blocks                            │
│           - 双缓冲机制                                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Round-Robin Scheduler                       │
│              - 分配blocks到不同pipeline                  │
│              - 跟踪pipeline状态                          │
└─────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┬──┘
      │      │      │      │      │      │      │      │
      ▼      ▼      ▼      ▼      ▼      ▼      ▼      ▼
   ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐
   │P0  │ │P1  │ │P2  │ │P3  │ │P4  │ │P5  │ │P6  │ │P7  │
   │Hash│ │Hash│ │Hash│ │Hash│ │Hash│ │Hash│ │Hash│ │Hash│
   │Core│ │Core│ │Core│ │Core│ │Core│ │Core│ │Core│ │Core│
   └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘ └─┬──┘
     │      │      │      │      │      │      │      │
     └──────┴──────┴──────┴──────┴──────┴──────┴──────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              Result Collector & Order Manager            │
│              - 收集各pipeline的结果                       │
│              - 保持结果顺序                              │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│              AXI-Stream Output Interface                 │
│              (256bit, 输出hash结果)                      │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Pipeline数量选择

根据性能分析：
- **MD5**: 需要11个pipeline
- **SHA256**: 需要13个pipeline
- **SHA1**: 需要14个pipeline

**选择**: 实现**16个并行pipeline**，可以满足所有算法的需求，并留有余量。

### 2.3 关键模块设计

#### 2.3.1 Round-Robin Scheduler
- 功能：将输入的512bit blocks分配到16个pipeline
- 策略：Round-robin轮询分配
- 状态跟踪：跟踪每个pipeline的busy/idle状态

#### 2.3.2 Pipeline Core
- 每个pipeline独立运行
- 支持MD5/SHA256/SHA1三种算法
- 深度pipeline优化

#### 2.3.3 Result Collector
- 收集各pipeline的hash结果
- 保持结果顺序（使用tag机制）
- 管理输出队列

## 3. 性能分析

### 3.1 吞吐率计算

假设16个pipeline，每个pipeline的cycle数：
- MD5: 45 cycles/block
- SHA256: 55 cycles/block
- SHA1: 60 cycles/block

**理论吞吐率**:
- MD5: 16 × 1.42 GB/s = **22.7 GB/s**
- SHA256: 16 × 1.16 GB/s = **18.6 GB/s**
- SHA1: 16 × 1.07 GB/s = **17.1 GB/s**

**结论**: 16个pipeline可以满足15GB/s的目标，并留有余量。

### 3.2 实际吞吐率考虑

考虑调度开销和结果收集延迟：
- 调度延迟: ~2 cycles
- 结果收集延迟: ~2 cycles
- 实际吞吐率约为理论值的90-95%

**预计实际吞吐率**:
- MD5: ~21 GB/s
- SHA256: ~17 GB/s
- SHA1: ~16 GB/s

## 4. 实现策略

### 4.1 模块划分
1. **scheduler.v**: Round-robin调度器
2. **pipeline_core.v**: 单个pipeline核心（支持三种算法）
3. **result_collector.v**: 结果收集器
4. **hash_top_multi.v**: 多pipeline顶层模块

### 4.2 关键设计点
1. **Tag机制**: 每个block分配tag，保证结果顺序
2. **双缓冲**: 输入/输出双缓冲，隐藏延迟
3. **Pipeline平衡**: 确保各pipeline负载均衡
4. **资源优化**: 共享常数表和函数计算单元

## 5. 资源估算（全部换算为LUT）

### 5.1 单Pipeline资源（LUT）
- **MD5 Core**: ~3,886 LUT
- **SHA256 Core**: ~7,716 LUT
- **SHA1 Core**: ~7,046 LUT
- **AXI Interface**: ~2,042 LUT
- **Block Formatter**: ~1,266 LUT
- **顶层**: ~402 LUT

**单Pipeline总计**:
- MD5: ~7,600 LUT
- SHA256: ~11,400 LUT
- SHA1: ~10,800 LUT

### 5.2 16 Pipeline资源（LUT）
- **16 × SHA256 Core**: ~123,456 LUT
- **16 × Pipeline Core包装器**: ~16,240 LUT
- **Scheduler**: ~1,433 LUT
- **Result Collector**: ~15,256 LUT
- **AXI Interface**: ~2,042 LUT（共享）
- **Block Formatter**: ~1,266 LUT（共享）
- **顶层**: ~802 LUT

**16 Pipeline总计**: **~150,000 LUT**（优化后）

**换算说明**: 1个寄存器(FF) ≈ 1.5 LUT（考虑时钟、复位、使能等控制逻辑）

## 6. 时序设计

### 6.1 关键路径
- Pipeline内部: 已优化到<1ns
- 调度器: 需要<1ns
- 结果收集器: 需要<1ns

### 6.2 时钟域
- 所有模块在同一时钟域（1GHz）
- 需要仔细设计pipeline stage之间的寄存器
