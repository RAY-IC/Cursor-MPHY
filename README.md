# 异步FIFO指针同步器原理示意图

## 文件说明

- `async_fifo_pointer_sync_diagram.png` / `.pdf` - 中文版示意图（可能因字体问题部分中文显示异常）
- `async_fifo_pointer_sync_diagram_en.png` / `.pdf` - 英文版示意图（推荐使用）
- `async_fifo_pointer_sync_diagram.py` - 中文版生成脚本
- `async_fifo_pointer_sync_diagram_en.py` - 英文版生成脚本

## 示意图说明

本示意图展示了异步FIFO中指针同步器的工作原理，假设两边的时钟是**同频不同步**的（Same Frequency, Out-of-Phase）。

### 关键组件

1. **写时钟域 (Write Clock Domain)**
   - Write Pointer：写指针计数器
   - Bin→Gray Converter：二进制到格雷码转换器
   - CLK_W：写时钟

2. **读时钟域 (Read Clock Domain)**
   - Read Pointer：读指针计数器
   - Gray→Bin Converter：格雷码到二进制转换器
   - CLK_R：读时钟

3. **指针同步器 (Pointer Synchronizer)**
   - FF1, FF2：双触发器同步器，将写指针同步到读时钟域
   - FF3, FF4：双触发器同步器，将读指针同步到写时钟域

### 工作原理

1. **格雷码编码**：指针使用格雷码编码，确保每次只有1位变化，减少跨时钟域传输时的亚稳态风险。

2. **双触发器同步**：使用两级触发器（2-FF Synchronizer）消除亚稳态问题：
   - 第一级触发器捕获异步信号
   - 第二级触发器稳定输出

3. **双向同步**：
   - 写指针（Gray码）→ 同步器（FF1, FF2）→ 读时钟域
   - 读指针（Gray码）→ 同步器（FF3, FF4）→ 写时钟域

4. **同频不同步时钟**：两个时钟频率相同但相位不同，这在某些系统中很常见（例如来自不同时钟源的相同频率时钟）。

### 使用方法

运行Python脚本生成示意图：

```bash
# 生成英文版（推荐）
python3 async_fifo_pointer_sync_diagram_en.py

# 生成中文版
python3 async_fifo_pointer_sync_diagram.py
```

生成的图片文件：
- PNG格式：高分辨率（300 DPI），适合查看和打印
- PDF格式：矢量图，适合文档插入和缩放
