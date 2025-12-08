# 2D DMA模块设计文档

## 概述

这是一个支持AXI4协议的2D图像DMA模块，具有以下特性：

1. **AXI4 Master接口**：支持outstanding事务（最多8个未完成传输）
2. **2D图像DMA**：支持基于tile的图像传输，可配置tile大小
3. **寄存器接口**：通过AXI4-Lite Slave接口进行配置

## 模块结构

### 1. dma_2d_axi.sv (顶层模块)
顶层模块，整合了所有子模块：
- AXI Master接口（内存访问）
- AXI Slave接口（寄存器配置）
- 2D DMA引擎
- 寄存器文件

### 2. dma_axi_master.sv (AXI Master接口)
实现AXI4 Master协议，支持：
- 写地址/数据/响应通道
- 读地址/数据通道
- Outstanding事务管理（最多MAX_OUTSTANDING个未完成传输）
- 突发传输支持

### 3. dma_2d_engine.sv (2D DMA引擎)
实现2D图像传输逻辑：
- Tile-based传输
- 可配置的tile大小（tile_width × tile_height）
- 支持frame buffer读写
- 自动计算tile地址

### 4. dma_regs.sv (寄存器定义)
寄存器地址映射和数据结构定义

## 寄存器映射

| 地址偏移 | 寄存器名称 | 描述 |
|---------|-----------|------|
| 0x00 | CTRL_REG | 控制寄存器，bit[31]=start |
| 0x04 | STATUS_REG | 状态寄存器，bit[31]=done, bit[30]=error |
| 0x08 | SRC_ADDR_REG | 源地址（frame buffer起始地址） |
| 0x0C | DST_ADDR_REG | 目标地址（frame buffer起始地址） |
| 0x10 | FRAME_WIDTH | 图像宽度（像素数） |
| 0x14 | FRAME_HEIGHT | 图像高度（像素数） |
| 0x18 | TILE_WIDTH | Tile宽度（像素数） |
| 0x1C | TILE_HEIGHT | Tile高度（像素数） |
| 0x20 | TILE_STRIDE | Tile之间的步长（字节） |
| 0x24 | PIXEL_STRIDE | 每个像素的字节数 |
| 0x28 | TRANSFER_SIZE | AXI传输大小（0=1B, 1=2B, 2=4B, 3=8B） |

## 使用方法

### 1. 配置参数

```systemverilog
dma_2d_axi #(
    .AXI_ADDR_WIDTH(32),      // AXI地址宽度
    .AXI_DATA_WIDTH(64),      // AXI数据宽度
    .AXI_ID_WIDTH(4),         // AXI ID宽度
    .MAX_OUTSTANDING(8),      // 最大outstanding事务数
    .REG_ADDR_WIDTH(8)        // 寄存器地址宽度
) u_dma (
    // 连接时钟和复位
    .clk(clk),
    .rst_n(rst_n),
    // 连接AXI Master接口到内存总线
    // 连接AXI Slave接口到CPU/配置总线
);
```

### 2. 配置步骤

1. **设置源地址**：写入SRC_ADDR_REG寄存器
2. **设置目标地址**：写入DST_ADDR_REG寄存器
3. **配置图像参数**：
   - FRAME_WIDTH: 图像宽度
   - FRAME_HEIGHT: 图像高度
   - TILE_WIDTH: Tile宽度
   - TILE_HEIGHT: Tile高度
   - TILE_STRIDE: Tile之间的步长
   - PIXEL_STRIDE: 每个像素的字节数（如RGB888=3, RGBA8888=4）
4. **设置传输大小**：写入TRANSFER_SIZE（通常为3，表示8字节）
5. **启动传输**：向CTRL_REG的bit[31]写入1

### 3. 监控状态

- 读取STATUS_REG寄存器：
  - bit[31] (done): 传输完成标志
  - bit[30] (error): 错误标志

## 工作原理

### Tile传输流程

1. **地址计算**：
   - 源tile地址 = src_base_addr + (tile_y × frame_width + tile_x × tile_width) × pixel_stride
   - 目标tile地址 = dst_base_addr + (tile_y × tile_stride + tile_x × tile_width × pixel_stride)

2. **传输顺序**：
   - 从左到右，从上到下依次传输每个tile
   - 每个tile作为一个AXI突发传输

3. **Outstanding支持**：
   - 可以同时发起多个AXI传输请求
   - 通过outstanding计数器管理未完成的传输
   - 最大支持MAX_OUTSTANDING个并发传输

### 示例场景

假设需要传输一个1920×1080的RGB888图像（3字节/像素），使用64×64的tile：

- FRAME_WIDTH = 1920
- FRAME_HEIGHT = 1080
- TILE_WIDTH = 64
- TILE_HEIGHT = 64
- PIXEL_STRIDE = 3
- TILE_STRIDE = 1920 × 3 = 5760（如果目标buffer也是连续存储）

每个tile大小 = 64 × 64 × 3 = 12,288 字节
每个tile的AXI beats = 12,288 / 8 = 1,536 beats

## 设计特点

1. **高性能**：
   - 支持outstanding事务，提高总线利用率
   - 突发传输减少地址开销

2. **灵活性**：
   - 可配置tile大小，适应不同应用场景
   - 支持不同的像素格式（通过pixel_stride配置）

3. **可靠性**：
   - 错误检测和报告
   - 状态寄存器提供传输状态

## 注意事项

1. **地址对齐**：建议源地址和目标地址按照AXI_DATA_WIDTH对齐
2. **Tile大小**：建议tile大小是AXI_DATA_WIDTH的倍数
3. **Outstanding限制**：确保MAX_OUTSTANDING不超过AXI总线的限制
4. **内部缓冲**：当前设计中的内部缓冲是简化的，实际应用中需要根据需求实现BRAM或使用外部内存

## 扩展建议

1. **内部缓冲**：实现真正的BRAM缓冲，支持读写流水线
2. **多通道支持**：支持多个DMA通道
3. **中断支持**：添加中断输出，在传输完成或错误时触发
4. **性能监控**：添加传输统计寄存器（传输字节数、传输时间等）
5. **数据格式转换**：添加像素格式转换功能

## 文件列表

- `dma_2d_axi.sv` - 顶层DMA模块
- `dma_axi_master.sv` - AXI Master接口模块
- `dma_2d_engine.sv` - 2D DMA引擎模块
- `dma_regs.sv` - 寄存器定义
- `README.md` - 本文档

## 版本历史

- v1.0 - 初始版本
  - 支持AXI4 Master接口
  - 支持outstanding事务
  - 支持2D图像DMA传输
  - 支持tile配置
