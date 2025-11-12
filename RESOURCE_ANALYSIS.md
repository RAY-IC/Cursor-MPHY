# 资源分析文档（LUT换算）

## 资源换算标准

### FPGA资源换算关系
- **1个寄存器 (FF)** ≈ **1.5 LUT**（考虑时钟、复位、使能等控制逻辑）
- **1个BRAM** ≈ **150 LUT**（如果使用BRAM，否则用寄存器实现）
- **1个DSP** ≈ **200-300 LUT**（本设计不使用DSP）

### 说明
本设计主要使用LUT和寄存器，不使用BRAM（使用寄存器实现存储），因此所有资源统一换算为LUT。

## 单Pipeline资源分析

### 1. MD5 Core (md5_core.v)

#### 寄存器资源
- Hash状态寄存器: 4 × 32bit = 128 bit
- 工作变量 (a,b,c,d): 4 × 32bit = 128 bit
- Pipeline寄存器: 512bit (block) + 16×32bit (W数组) + 6bit (counter) + 2bit (state) = 512 + 512 + 6 + 2 = 1032 bit
- 临时变量: 32bit (round_temp) + 4bit (w_idx) = 36 bit
- **总计寄存器**: ~1324 bit ≈ **1324个FF**

#### LUT资源（组合逻辑）
- F/G/H/I函数: 4个函数 × 32bit × 3输入 ≈ 400 LUT
- 左旋转 (rotate_left): 32bit barrel shifter ≈ 200 LUT
- 加法器链: 4个32bit加法器 ≈ 300 LUT
- 常数表 (K数组): 64个常数，使用MUX实现 ≈ 500 LUT
- 移位表 (S数组): 64个移位值，使用MUX实现 ≈ 300 LUT
- 控制逻辑: 状态机、计数器等 ≈ 200 LUT
- **总计LUT**: ~1900 LUT

#### 总资源（换算为LUT）
- 寄存器: 1324 FF × 1.5 = **1986 LUT**
- 组合逻辑: **1900 LUT**
- **MD5 Core总计**: **~3886 LUT**

### 2. SHA256 Core (sha256_core.v)

#### 寄存器资源
- Hash状态寄存器: 8 × 32bit = 256 bit
- 工作变量 (a-h): 8 × 32bit = 256 bit
- Pipeline寄存器: 512bit (block) + 64×32bit (W数组) + 6bit (counter) + 2bit (state) = 512 + 2048 + 6 + 2 = 2568 bit
- 临时变量: 2 × 32bit (T1, T2) = 64 bit
- **总计寄存器**: ~3144 bit ≈ **3144个FF**

#### LUT资源（组合逻辑）
- Ch/Maj函数: 2个函数 × 32bit × 3输入 ≈ 300 LUT
- Σ0/Σ1函数: 2个函数 × 32bit ≈ 400 LUT
- σ0/σ1函数: 2个函数 × 32bit ≈ 400 LUT
- 消息扩展逻辑: 复杂的组合逻辑 ≈ 600 LUT
- 加法器链: 多个32bit加法器 ≈ 500 LUT
- 常数表 (K数组): 64个常数 ≈ 500 LUT
- 控制逻辑: 状态机、计数器等 ≈ 300 LUT
- **总计LUT**: ~3000 LUT

#### 总资源（换算为LUT）
- 寄存器: 3144 FF × 1.5 = **4716 LUT**
- 组合逻辑: **3000 LUT**
- **SHA256 Core总计**: **~7716 LUT**

### 3. SHA1 Core (sha1_core.v)

#### 寄存器资源
- Hash状态寄存器: 5 × 32bit = 160 bit
- 工作变量 (a-e): 5 × 32bit = 160 bit
- Pipeline寄存器: 512bit (block) + 80×32bit (W数组) + 7bit (counter) + 2bit (state) = 512 + 2560 + 7 + 2 = 3081 bit
- 临时变量: 3 × 32bit (f_result, k_const, temp) = 96 bit
- **总计寄存器**: ~3497 bit ≈ **3497个FF**

#### LUT资源（组合逻辑）
- f0/f1/f2函数: 3个函数 × 32bit × 3输入 ≈ 400 LUT
- 左旋转 (rotate_left): 32bit barrel shifter ≈ 200 LUT
- 消息扩展逻辑: XOR和旋转组合 ≈ 500 LUT
- 加法器链: 5个32bit加法器 ≈ 400 LUT
- 控制逻辑: 状态机、计数器等 ≈ 300 LUT
- **总计LUT**: ~1800 LUT

#### 总资源（换算为LUT）
- 寄存器: 3497 FF × 1.5 = **5246 LUT**
- 组合逻辑: **1800 LUT**
- **SHA1 Core总计**: **~7046 LUT**

### 4. AXI Stream Interface (axi_stream_if.v)

#### 寄存器资源
- 输入缓冲: 256bit + 512bit (full_block) + 1bit (half_full) = 769 bit
- 输出缓冲: 256bit + 2bit (state) = 258 bit
- 控制寄存器: 1bit (ready) = 1 bit
- **总计寄存器**: ~1028 bit ≈ **1028个FF**

#### LUT资源
- 数据路径逻辑: MUX、数据重组等 ≈ 300 LUT
- 控制逻辑: 状态机、握手协议等 ≈ 200 LUT
- **总计LUT**: ~500 LUT

#### 总资源（换算为LUT）
- 寄存器: 1028 FF × 1.5 = **1542 LUT**
- 组合逻辑: **500 LUT**
- **AXI Interface总计**: **~2042 LUT**

### 5. Block Formatter (block_formatter.v)

#### 寄存器资源
- Block缓冲: 512bit = 512 bit
- 长度寄存器: 64bit = 64 bit
- 状态寄存器: 1bit = 1 bit
- **总计寄存器**: ~577 bit ≈ **577个FF**

#### LUT资源
- Padding逻辑: 组合逻辑 ≈ 200 LUT
- 长度编码: 组合逻辑 ≈ 100 LUT
- 控制逻辑: 状态机 ≈ 100 LUT
- **总计LUT**: ~400 LUT

#### 总资源（换算为LUT）
- 寄存器: 577 FF × 1.5 = **866 LUT**
- 组合逻辑: **400 LUT**
- **Block Formatter总计**: **~1266 LUT**

### 6. 单Pipeline顶层 (hash_top.v)

#### 寄存器资源
- 算法选择寄存器: 2bit = 2 bit
- 长度计数器: 64bit = 64 bit
- 控制寄存器: 2bit (done, ready) = 2 bit
- **总计寄存器**: ~68 bit ≈ **68个FF**

#### LUT资源
- 算法路由逻辑: MUX等 ≈ 200 LUT
- 控制逻辑: ≈ 100 LUT
- **总计LUT**: ~300 LUT

#### 总资源（换算为LUT）
- 寄存器: 68 FF × 1.5 = **102 LUT**
- 组合逻辑: **300 LUT**
- **顶层总计**: **~402 LUT**

## 单Pipeline总资源汇总

### 按算法分类

#### MD5单Pipeline
- MD5 Core: 3886 LUT
- AXI Interface: 2042 LUT
- Block Formatter: 1266 LUT
- 顶层: 402 LUT
- **MD5单Pipeline总计**: **~7596 LUT**

#### SHA256单Pipeline
- SHA256 Core: 7716 LUT
- AXI Interface: 2042 LUT
- Block Formatter: 1266 LUT
- 顶层: 402 LUT
- **SHA256单Pipeline总计**: **~11426 LUT**

#### SHA1单Pipeline
- SHA1 Core: 7046 LUT
- AXI Interface: 2042 LUT
- Block Formatter: 1266 LUT
- 顶层: 402 LUT
- **SHA1单Pipeline总计**: **~10756 LUT**

### 平均单Pipeline资源
- **平均**: ~9900 LUT（取SHA256作为最坏情况）

## 多Pipeline资源分析

### 1. Scheduler (scheduler.v)

#### 寄存器资源
- Pipeline指针: 4bit = 4 bit
- Tag计数器: 8bit = 8 bit
- Block tag: 8bit = 8 bit
- 状态寄存器: 2bit = 2 bit
- **总计寄存器**: ~22 bit ≈ **22个FF**

#### LUT资源
- Pipeline选择逻辑: 16路MUX和比较器 ≈ 800 LUT
- Round-robin逻辑: 组合逻辑 ≈ 400 LUT
- 控制逻辑: 状态机 ≈ 200 LUT
- **总计LUT**: ~1400 LUT

#### 总资源（换算为LUT）
- 寄存器: 22 FF × 1.5 = **33 LUT**
- 组合逻辑: **1400 LUT**
- **Scheduler总计**: **~1433 LUT**

### 2. Pipeline Core (pipeline_core.v)

#### 寄存器资源
- Tag寄存器: 8bit = 8 bit
- Busy/Done寄存器: 2bit = 2 bit
- **总计寄存器**: ~10 bit ≈ **10个FF**

#### LUT资源
- 算法选择MUX: 3路MUX (256bit) ≈ 800 LUT
- 控制逻辑: ≈ 200 LUT
- **总计LUT**: ~1000 LUT

#### 总资源（换算为LUT）
- 寄存器: 10 FF × 1.5 = **15 LUT**
- 组合逻辑: **1000 LUT**
- **Pipeline Core包装器总计**: **~1015 LUT**

### 3. Result Collector (result_collector.v)

#### 寄存器资源
- 结果队列: 32 × 256bit = 8192 bit
- Tag队列: 32 × 8bit = 256 bit
- 有效位队列: 32 × 1bit = 32 bit
- 队列指针: 2 × 5bit = 10 bit
- 队列计数: 6bit = 6 bit
- 期望tag: 8bit = 8 bit
- **总计寄存器**: ~8504 bit ≈ **8504个FF**

#### LUT资源
- Pipeline选择逻辑: 16路比较和MUX ≈ 1200 LUT
- 队列管理逻辑: 读写指针、计数等 ≈ 400 LUT
- Tag匹配逻辑: 比较器阵列 ≈ 600 LUT
- 控制逻辑: 状态机 ≈ 300 LUT
- **总计LUT**: ~2500 LUT

#### 总资源（换算为LUT）
- 寄存器: 8504 FF × 1.5 = **12756 LUT**
- 组合逻辑: **2500 LUT**
- **Result Collector总计**: **~15256 LUT**

### 4. 多Pipeline顶层 (hash_top_multi.v)

#### 寄存器资源
- 算法选择: 2bit = 2 bit
- 长度计数器: 64bit = 64 bit
- 控制寄存器: 2bit = 2 bit
- **总计寄存器**: ~68 bit ≈ **68个FF**

#### LUT资源
- 16个Pipeline实例化: 主要是连线，少量逻辑 ≈ 500 LUT
- 控制逻辑: ≈ 200 LUT
- **总计LUT**: ~700 LUT

#### 总资源（换算为LUT）
- 寄存器: 68 FF × 1.5 = **102 LUT**
- 组合逻辑: **700 LUT**
- **多Pipeline顶层总计**: **~802 LUT**

## 16 Pipeline总资源汇总

### 核心Pipeline资源（16个）
假设使用SHA256（最坏情况）:
- 16 × SHA256 Core: 16 × 7716 = **123456 LUT**
- 16 × Pipeline Core包装器: 16 × 1015 = **16240 LUT**
- **Pipeline总计**: **~139696 LUT**

### 共享资源
- Scheduler: **1433 LUT**
- Result Collector: **15256 LUT**
- AXI Interface: **2042 LUT**（共享）
- Block Formatter: **1266 LUT**（共享）
- 多Pipeline顶层: **802 LUT**

### 16 Pipeline总资源
- Pipeline核心: 139696 LUT
- 调度和收集: 1433 + 15256 = 16689 LUT
- 接口和格式化: 2042 + 1266 = 3308 LUT
- 顶层: 802 LUT
- **16 Pipeline总计**: **~160495 LUT**

### 资源优化估算
考虑到资源共享和优化:
- 常数表可以共享: 节省 ~8000 LUT
- 部分控制逻辑共享: 节省 ~2000 LUT
- **优化后16 Pipeline总计**: **~150000 LUT**

## 资源对比表

| 模块 | 单Pipeline (LUT) | 16 Pipeline (LUT) | 说明 |
|------|-----------------|-------------------|------|
| MD5 Core | 3,886 | 62,176 | 16个实例 |
| SHA256 Core | 7,716 | 123,456 | 16个实例 |
| SHA1 Core | 7,046 | 112,736 | 16个实例 |
| AXI Interface | 2,042 | 2,042 | 共享 |
| Block Formatter | 1,266 | 1,266 | 共享 |
| Scheduler | - | 1,433 | 仅多pipeline |
| Pipeline Core包装 | - | 16,240 | 16个实例 |
| Result Collector | - | 15,256 | 仅多pipeline |
| 顶层 | 402 | 802 | 共享 |
| **MD5总资源** | **7,596** | **~120,000** | 优化后 |
| **SHA256总资源** | **11,426** | **~150,000** | 优化后 |
| **SHA1总资源** | **10,756** | **~140,000** | 优化后 |

## 资源使用建议

### FPGA选择建议
- **单Pipeline**: 需要 ~12K LUT，适合中等规模FPGA（如Xilinx Artix-7, Intel Cyclone V）
- **16 Pipeline**: 需要 ~150K LUT，适合大规模FPGA（如Xilinx Kintex-7/Virtex-7, Intel Stratix V）

### 资源优化建议
1. **共享常数表**: 可以节省约8K LUT
2. **使用BRAM**: 对于大数组（如W数组），使用BRAM可以节省LUT
3. **Pipeline数量可配置**: 根据实际需求选择8/12/16个pipeline
4. **算法选择**: 如果只使用一种算法，可以移除其他算法核心

## 总结

### 单Pipeline资源
- **MD5**: ~7,600 LUT
- **SHA256**: ~11,400 LUT
- **SHA1**: ~10,800 LUT

### 16 Pipeline资源（优化后）
- **MD5**: ~120,000 LUT
- **SHA256**: ~150,000 LUT
- **SHA1**: ~140,000 LUT

**结论**: 16 Pipeline版本需要约150K LUT，适合大规模FPGA实现。
