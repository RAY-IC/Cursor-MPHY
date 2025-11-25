#!/usr/bin/env python3
"""
异步FIFO指针同步器原理示意图
假设两边的时钟是同频不同步的
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Rectangle
import numpy as np

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['DejaVu Sans', 'Arial Unicode MS', 'SimHei']
plt.rcParams['axes.unicode_minus'] = False

fig, ax = plt.subplots(1, 1, figsize=(16, 10))
ax.set_xlim(0, 16)
ax.set_ylim(0, 10)
ax.axis('off')

# 定义颜色
color_write_domain = '#E3F2FD'  # 浅蓝色 - 写时钟域
color_read_domain = '#FFF3E0'   # 浅橙色 - 读时钟域
color_sync = '#C8E6C9'          # 浅绿色 - 同步器
color_clock = '#FF5252'         # 红色 - 时钟信号
color_data = '#2196F3'          # 蓝色 - 数据信号
color_gray = '#9E9E9E'          # 灰色 - 格雷码

# ========== 写时钟域 (左侧) ==========
write_x = 1
write_y = 5.5
write_width = 3
write_height = 3.5

write_box = FancyBboxPatch((write_x, write_y), write_width, write_height,
                           boxstyle="round,pad=0.1", 
                           facecolor=color_write_domain,
                           edgecolor='black', linewidth=2)
ax.add_patch(write_box)
ax.text(write_x + write_width/2, write_y + write_height - 0.3, 
        '写时钟域\n(Write Clock Domain)', 
        ha='center', va='top', fontsize=12, weight='bold')

# 写指针计数器
write_ptr_x = write_x + 0.3
write_ptr_y = write_y + 2
write_ptr_box = Rectangle((write_ptr_x, write_ptr_y), 1.2, 0.8,
                         facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(write_ptr_box)
ax.text(write_ptr_x + 0.6, write_ptr_y + 0.4, 'Write\nPointer', 
        ha='center', va='center', fontsize=9)

# 二进制到格雷码转换
gray_conv_x = write_x + 1.8
gray_conv_y = write_y + 2
gray_conv_box = Rectangle((gray_conv_x, gray_conv_y), 1.2, 0.8,
                          facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(gray_conv_box)
ax.text(gray_conv_x + 0.6, gray_conv_y + 0.4, 'Bin→Gray\nConverter', 
        ha='center', va='center', fontsize=8)

# 写时钟
write_clk_x = write_x + 0.3
write_clk_y = write_y + 0.5
write_clk_circle = Circle((write_clk_x + 0.3, write_clk_y + 0.3), 0.25,
                         facecolor='white', edgecolor=color_clock, linewidth=2)
ax.add_patch(write_clk_circle)
ax.text(write_clk_x + 0.3, write_clk_y + 0.3, 'W', ha='center', va='center', 
        fontsize=10, weight='bold', color=color_clock)
ax.text(write_clk_x + 0.3, write_clk_y - 0.2, 'CLK_W', ha='center', va='top', 
        fontsize=9, color=color_clock)

# 写指针格雷码输出
write_gray_x = write_x + write_width/2
write_gray_y = write_y - 0.3
ax.text(write_gray_x, write_gray_y, 'Write Pointer (Gray)', 
        ha='center', va='top', fontsize=9, style='italic', color=color_gray)

# ========== 读时钟域 (右侧) ==========
read_x = 12
read_y = 5.5
read_width = 3
read_height = 3.5

read_box = FancyBboxPatch((read_x, read_y), read_width, read_height,
                         boxstyle="round,pad=0.1", 
                         facecolor=color_read_domain,
                         edgecolor='black', linewidth=2)
ax.add_patch(read_box)
ax.text(read_x + read_width/2, read_y + read_height - 0.3, 
        '读时钟域\n(Read Clock Domain)', 
        ha='center', va='top', fontsize=12, weight='bold')

# 读指针计数器
read_ptr_x = read_x + 1.5
read_ptr_y = write_y + 2
read_ptr_box = Rectangle((read_ptr_x, read_ptr_y), 1.2, 0.8,
                        facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(read_ptr_box)
ax.text(read_ptr_x + 0.6, read_ptr_y + 0.4, 'Read\nPointer', 
        ha='center', va='center', fontsize=9)

# 格雷码到二进制转换
gray_conv_r_x = read_x + 0.3
gray_conv_r_y = write_y + 2
gray_conv_r_box = Rectangle((gray_conv_r_x, gray_conv_r_y), 1.2, 0.8,
                            facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(gray_conv_r_box)
ax.text(gray_conv_r_x + 0.6, gray_conv_r_y + 0.4, 'Gray→Bin\nConverter', 
        ha='center', va='center', fontsize=8)

# 读时钟
read_clk_x = read_x + 2.4
read_clk_y = write_y + 0.5
read_clk_circle = Circle((read_clk_x + 0.3, read_clk_y + 0.3), 0.25,
                        facecolor='white', edgecolor=color_clock, linewidth=2)
ax.add_patch(read_clk_circle)
ax.text(read_clk_x + 0.3, read_clk_y + 0.3, 'R', ha='center', va='center', 
        fontsize=10, weight='bold', color=color_clock)
ax.text(read_clk_x + 0.3, read_clk_y - 0.2, 'CLK_R', ha='center', va='top', 
        fontsize=9, color=color_clock)

# 读指针格雷码输出
read_gray_x = read_x + read_width/2
read_gray_y = write_y - 0.3
ax.text(read_gray_x, read_gray_y, 'Read Pointer (Gray)', 
        ha='center', va='top', fontsize=9, style='italic', color=color_gray)

# ========== 同步器 (中间) ==========
sync_x = 6.5
sync_y = 5.5
sync_width = 3
sync_height = 3.5

sync_box = FancyBboxPatch((sync_x, sync_y), sync_width, sync_height,
                         boxstyle="round,pad=0.1", 
                         facecolor=color_sync,
                         edgecolor='black', linewidth=2)
ax.add_patch(sync_box)
ax.text(sync_x + sync_width/2, sync_y + sync_height - 0.3, 
        '指针同步器\n(Pointer Synchronizer)', 
        ha='center', va='top', fontsize=11, weight='bold')

# 双触发器同步器 (写指针同步到读时钟域)
sync1_x = sync_x + 0.3
sync1_y = sync_y + 2.2
sync1_box = Rectangle((sync1_x, sync1_y), 1, 0.6,
                     facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(sync1_box)
ax.text(sync1_x + 0.5, sync1_y + 0.3, 'FF1', ha='center', va='center', fontsize=8)

sync2_x = sync_x + 1.7
sync2_y = sync_y + 2.2
sync2_box = Rectangle((sync2_x, sync2_y), 1, 0.6,
                     facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(sync2_box)
ax.text(sync2_x + 0.5, sync2_y + 0.3, 'FF2', ha='center', va='center', fontsize=8)

ax.text(sync_x + sync_width/2, sync1_y - 0.2, 'Write Ptr → Read Domain', 
        ha='center', va='top', fontsize=8, style='italic')

# 双触发器同步器 (读指针同步到写时钟域)
sync3_x = sync_x + 0.3
sync3_y = sync_y + 0.8
sync3_box = Rectangle((sync3_x, sync3_y), 1, 0.6,
                     facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(sync3_box)
ax.text(sync3_x + 0.5, sync3_y + 0.3, 'FF3', ha='center', va='center', fontsize=8)

sync4_x = sync_x + 1.7
sync4_y = sync_y + 0.8
sync4_box = Rectangle((sync4_x, sync4_y), 1, 0.6,
                     facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(sync4_box)
ax.text(sync4_x + 0.5, sync4_y + 0.3, 'FF4', ha='center', va='center', fontsize=8)

ax.text(sync_x + sync_width/2, sync3_y - 0.2, 'Read Ptr → Write Domain', 
        ha='center', va='top', fontsize=8, style='italic')

# ========== 箭头连接 ==========
# 写指针到同步器
arrow1 = FancyArrowPatch((write_x + write_width, write_y + write_height/2),
                        (sync_x, sync_y + sync_height - 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow1)

# 同步器到读时钟域
arrow2 = FancyArrowPatch((sync_x + sync_width, sync_y + sync_height - 0.8),
                        (read_x, read_y + read_height - 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow2)

# 读指针到同步器
arrow3 = FancyArrowPatch((read_x, read_y + 0.8),
                        (sync_x + sync_width, sync_y + 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow3)

# 同步器到写时钟域
arrow4 = FancyArrowPatch((sync_x, read_y + 0.8),
                        (write_x + write_width, write_y + 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow4)

# 时钟信号到同步器
# 写时钟到同步器FF3, FF4
arrow_clk_w1 = FancyArrowPatch((write_clk_x + 0.3, write_clk_y + 0.3),
                              (sync3_x, sync3_y + 0.3),
                              arrowstyle='->', mutation_scale=15, 
                              linewidth=1.5, color=color_clock, 
                              linestyle='--', zorder=1)
ax.add_patch(arrow_clk_w1)

arrow_clk_w2 = FancyArrowPatch((write_clk_x + 0.3, write_clk_y + 0.3),
                              (sync4_x, sync4_y + 0.3),
                              arrowstyle='->', mutation_scale=15, 
                              linewidth=1.5, color=color_clock, 
                              linestyle='--', zorder=1)
ax.add_patch(arrow_clk_w2)

# 读时钟到同步器FF1, FF2
arrow_clk_r1 = FancyArrowPatch((read_clk_x + 0.3, read_clk_y + 0.3),
                              (sync1_x, sync1_y + 0.3),
                              arrowstyle='->', mutation_scale=15, 
                              linewidth=1.5, color=color_clock, 
                              linestyle='--', zorder=1)
ax.add_patch(arrow_clk_r1)

arrow_clk_r2 = FancyArrowPatch((read_clk_x + 0.3, read_clk_y + 0.3),
                              (sync2_x, sync2_y + 0.3),
                              arrowstyle='->', mutation_scale=15, 
                              linewidth=1.5, color=color_clock, 
                              linestyle='--', zorder=1)
ax.add_patch(arrow_clk_r2)

# ========== 时钟波形示意图 (底部) ==========
wave_y = 1.5
wave_height = 1.2

# 写时钟波形
wave_w_x_start = write_x + 0.5
wave_w_x_end = write_x + write_width - 0.5
wave_w_period = (wave_w_x_end - wave_w_x_start) / 2
wave_w_points = 100
wave_w_x = np.linspace(wave_w_x_start, wave_w_x_end, wave_w_points)
wave_w_y = wave_y + wave_height/2 + wave_height/4 * np.sign(np.sin(2 * np.pi * 2 * (wave_w_x - wave_w_x_start) / (wave_w_x_end - wave_w_x_start)))
ax.plot(wave_w_x, wave_w_y, color=color_clock, linewidth=2)
ax.text(wave_w_x_start + (wave_w_x_end - wave_w_x_start)/2, wave_y + wave_height + 0.1,
        'CLK_W (同频不同相)', ha='center', va='bottom', fontsize=9, color=color_clock)

# 读时钟波形 (相位偏移)
wave_r_x_start = read_x + 0.5
wave_r_x_end = read_x + read_width - 0.5
wave_r_period = (wave_r_x_end - wave_r_x_start) / 2
wave_r_points = 100
wave_r_x = np.linspace(wave_r_x_start, wave_r_x_end, wave_r_points)
# 相位偏移约30度
phase_offset = np.pi / 6
wave_r_y = wave_y + wave_height/2 + wave_height/4 * np.sign(np.sin(2 * np.pi * 2 * (wave_r_x - wave_r_x_start) / (wave_r_x_end - wave_r_x_start) + phase_offset))
ax.plot(wave_r_x, wave_r_y, color=color_clock, linewidth=2, linestyle='--')
ax.text(wave_r_x_start + (wave_r_x_end - wave_r_x_start)/2, wave_y + wave_height + 0.1,
        'CLK_R (同频不同相)', ha='center', va='bottom', fontsize=9, color=color_clock)

# ========== 说明文字 ==========
info_text = """
关键特性：
1. 使用格雷码(Gray Code)编码指针，确保每次只有1位变化
2. 双触发器同步器(2-FF Synchronizer)消除亚稳态
3. 同频不同步时钟：频率相同但相位不同
4. 写指针同步到读时钟域，读指针同步到写时钟域
5. 同步后的指针用于空/满判断
"""

ax.text(8, 0.3, info_text, ha='center', va='bottom', fontsize=9,
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))

# 标题
ax.text(8, 9.5, '异步FIFO指针同步器原理示意图\n(同频不同步时钟)', 
        ha='center', va='top', fontsize=16, weight='bold')

plt.tight_layout()
plt.savefig('/workspace/async_fifo_pointer_sync_diagram.png', dpi=300, bbox_inches='tight')
plt.savefig('/workspace/async_fifo_pointer_sync_diagram.pdf', bbox_inches='tight')
print("示意图已生成: async_fifo_pointer_sync_diagram.png 和 .pdf")
