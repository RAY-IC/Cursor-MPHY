# 多Pipeline高性能HASH模块设计文档

## 概述

本设计实现了支持15GB/s吞吐率的多pipeline并行HASH模块，采用16个并行pipeline架构，支持MD5、SHA256和SHA1三种算法。

## 架构特点

### 1. 多Pipeline并行架构
- **16个并行pipeline**: 满足15GB/s吞吐率需求
- **Round-robin调度**: 均匀分配blocks到各pipeline
- **Tag机制**: 保证结果输出顺序

### 2. 关键模块

#### 2.1 Scheduler (scheduler.v)
- Round-robin调度器
- 将512bit blocks分配到16个pipeline
- 跟踪pipeline状态，选择可用pipeline
- 为每个block分配tag用于结果排序

#### 2.2 Pipeline Core (pipeline_core.v)
- 单个pipeline核心模块
- 支持MD5/SHA256/SHA1三种算法
- 复用单pipeline版本的算法核心

#### 2.3 Result Collector (result_collector.v)
- 收集各pipeline的hash结果
- 使用队列保持结果顺序
- 根据tag重新排序输出

#### 2.4 Top Module (hash_top_multi.v)
- 集成所有模块
- 16个pipeline实例化
- 统一的AXI-Stream接口

## 性能分析

### 理论吞吐率

| 算法 | 单Pipeline Cycle数 | 单Pipeline吞吐率 | 16 Pipeline理论吞吐率 |
|------|-------------------|------------------|---------------------|
| MD5  | 45 cycles         | 1.42 GB/s        | 22.7 GB/s           |
| SHA256 | 55 cycles       | 1.16 GB/s        | 18.6 GB/s           |
| SHA1 | 60 cycles         | 1.07 GB/s        | 17.1 GB/s           |

### 实际吞吐率

考虑调度和收集开销（约5-10%）：
- **MD5**: ~21 GB/s
- **SHA256**: ~17 GB/s  
- **SHA1**: ~16 GB/s

**结论**: 16个pipeline可以满足15GB/s的目标吞吐率。

## 文件结构

```
/workspace/
├── MULTI_PIPELINE_ARCHITECTURE.md  # 多pipeline架构设计文档
├── scheduler.v                     # Round-robin调度器
├── pipeline_core.v                 # 单个pipeline核心
├── result_collector.v              # 结果收集器
├── hash_top_multi.v                # 多pipeline顶层模块
└── tb_hash_top_multi.v             # 性能测试testbench
```

## 使用方法

### 仿真

```bash
# 编译所有模块
vlog axi_stream_if.v
vlog block_formatter.v
vlog md5_core.v
vlog sha256_core.v
vlog sha1_core.v
vlog scheduler.v
vlog pipeline_core.v
vlog result_collector.v
vlog hash_top_multi.v
vlog tb_hash_top_multi.v

# 运行性能测试
vsim -c tb_hash_top_multi -do "run -all"
```

### 接口说明

接口与单pipeline版本相同：
- **AXI-Stream输入**: 256bit数据流
- **AXI-Stream输出**: 256bit hash结果
- **算法选择**: algorithm_sel[1:0]
- **控制信号**: start, ready, done

## 设计优化

### 1. Pipeline数量选择
- 选择16个pipeline以满足所有算法的需求
- 留有余量应对实际开销

### 2. 调度策略
- Round-robin确保负载均衡
- 动态选择可用pipeline提高效率

### 3. 结果排序
- Tag机制保证结果顺序
- 队列缓冲处理乱序结果

### 4. 资源优化
- 共享常数表
- Pipeline间资源共享

## 资源估算

### 单Pipeline资源
- 寄存器: ~2,000个
- LUT: ~3,000个

### 16 Pipeline总资源
- Pipeline核心: ~48,000 LUT, ~32,000寄存器
- 调度器: ~5,000 LUT
- 结果收集器: ~3,000 LUT
- **总计**: ~56,000 LUT, ~32,000寄存器

## 性能测试

Testbench包含以下测试：
1. 64KB数据吞吐率测试
2. 256KB数据吞吐率测试
3. 1MB数据吞吐率测试
4. 不同算法的性能对比

## 扩展性

### 调整Pipeline数量
可以通过修改`NUM_PIPELINES`参数调整pipeline数量：
- 8个pipeline: ~10-12 GB/s
- 16个pipeline: ~17-21 GB/s (当前)
- 32个pipeline: ~35-42 GB/s

### 进一步优化
1. **更深度的Pipeline**: 进一步减少cycle数
2. **更好的调度算法**: 考虑pipeline负载
3. **更大的结果队列**: 处理更多乱序结果
4. **预取机制**: 提前准备下一个block

## 注意事项

1. **时序约束**: 1GHz时钟需要严格的时序约束
2. **资源使用**: 多pipeline会显著增加资源使用
3. **功耗**: 16个并行pipeline功耗较高
4. **测试**: 需要大量测试数据验证性能

## 版本历史

- v2.0: 多pipeline版本，支持15GB/s吞吐率
- v1.0: 单pipeline版本
