#!/usr/bin/env python3
"""
Asynchronous FIFO Pointer Synchronizer Schematic Diagram
Assumes clocks are same frequency but out of phase
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Rectangle
import numpy as np

fig, ax = plt.subplots(1, 1, figsize=(16, 10))
ax.set_xlim(0, 16)
ax.set_ylim(0, 10)
ax.axis('off')

# Define colors
color_write_domain = '#E3F2FD'  # Light blue - Write clock domain
color_read_domain = '#FFF3E0'   # Light orange - Read clock domain
color_sync = '#C8E6C9'          # Light green - Synchronizer
color_clock = '#FF5252'         # Red - Clock signal
color_data = '#2196F3'          # Blue - Data signal
color_gray = '#9E9E9E'          # Gray - Gray code

# ========== Write Clock Domain (Left) ==========
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
        'Write Clock Domain\n(CLK_W)', 
        ha='center', va='top', fontsize=12, weight='bold')

# Write pointer counter
write_ptr_x = write_x + 0.3
write_ptr_y = write_y + 2
write_ptr_box = Rectangle((write_ptr_x, write_ptr_y), 1.2, 0.8,
                         facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(write_ptr_box)
ax.text(write_ptr_x + 0.6, write_ptr_y + 0.4, 'Write\nPointer', 
        ha='center', va='center', fontsize=9)

# Binary to Gray code converter
gray_conv_x = write_x + 1.8
gray_conv_y = write_y + 2
gray_conv_box = Rectangle((gray_conv_x, gray_conv_y), 1.2, 0.8,
                          facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(gray_conv_box)
ax.text(gray_conv_x + 0.6, gray_conv_y + 0.4, 'Bin→Gray\nConverter', 
        ha='center', va='center', fontsize=8)

# Write clock
write_clk_x = write_x + 0.3
write_clk_y = write_y + 0.5
write_clk_circle = Circle((write_clk_x + 0.3, write_clk_y + 0.3), 0.25,
                         facecolor='white', edgecolor=color_clock, linewidth=2)
ax.add_patch(write_clk_circle)
ax.text(write_clk_x + 0.3, write_clk_y + 0.3, 'W', ha='center', va='center', 
        fontsize=10, weight='bold', color=color_clock)
ax.text(write_clk_x + 0.3, write_clk_y - 0.2, 'CLK_W', ha='center', va='top', 
        fontsize=9, color=color_clock)

# Write pointer Gray code output
write_gray_x = write_x + write_width/2
write_gray_y = write_y - 0.3
ax.text(write_gray_x, write_gray_y, 'Write Pointer (Gray)', 
        ha='center', va='top', fontsize=9, style='italic', color=color_gray)

# ========== Read Clock Domain (Right) ==========
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
        'Read Clock Domain\n(CLK_R)', 
        ha='center', va='top', fontsize=12, weight='bold')

# Read pointer counter
read_ptr_x = read_x + 1.5
read_ptr_y = write_y + 2
read_ptr_box = Rectangle((read_ptr_x, read_ptr_y), 1.2, 0.8,
                        facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(read_ptr_box)
ax.text(read_ptr_x + 0.6, read_ptr_y + 0.4, 'Read\nPointer', 
        ha='center', va='center', fontsize=9)

# Gray code to binary converter
gray_conv_r_x = read_x + 0.3
gray_conv_r_y = write_y + 2
gray_conv_r_box = Rectangle((gray_conv_r_x, gray_conv_r_y), 1.2, 0.8,
                            facecolor='white', edgecolor='black', linewidth=1.5)
ax.add_patch(gray_conv_r_box)
ax.text(gray_conv_r_x + 0.6, gray_conv_r_y + 0.4, 'Gray→Bin\nConverter', 
        ha='center', va='center', fontsize=8)

# Read clock
read_clk_x = read_x + 2.4
read_clk_y = write_y + 0.5
read_clk_circle = Circle((read_clk_x + 0.3, read_clk_y + 0.3), 0.25,
                        facecolor='white', edgecolor=color_clock, linewidth=2)
ax.add_patch(read_clk_circle)
ax.text(read_clk_x + 0.3, read_clk_y + 0.3, 'R', ha='center', va='center', 
        fontsize=10, weight='bold', color=color_clock)
ax.text(read_clk_x + 0.3, read_clk_y - 0.2, 'CLK_R', ha='center', va='top', 
        fontsize=9, color=color_clock)

# Read pointer Gray code output
read_gray_x = read_x + read_width/2
read_gray_y = write_y - 0.3
ax.text(read_gray_x, read_gray_y, 'Read Pointer (Gray)', 
        ha='center', va='top', fontsize=9, style='italic', color=color_gray)

# ========== Synchronizer (Middle) ==========
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
        'Pointer Synchronizer\n(2-FF Synchronizer)', 
        ha='center', va='top', fontsize=11, weight='bold')

# Dual flip-flop synchronizer (Write pointer sync to read domain)
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

# Dual flip-flop synchronizer (Read pointer sync to write domain)
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

# ========== Arrow Connections ==========
# Write pointer to synchronizer
arrow1 = FancyArrowPatch((write_x + write_width, write_y + write_height/2),
                        (sync_x, sync_y + sync_height - 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow1)

# Synchronizer to read clock domain
arrow2 = FancyArrowPatch((sync_x + sync_width, sync_y + sync_height - 0.8),
                        (read_x, read_y + read_height - 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow2)

# Read pointer to synchronizer
arrow3 = FancyArrowPatch((read_x, read_y + 0.8),
                        (sync_x + sync_width, sync_y + 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow3)

# Synchronizer to write clock domain
arrow4 = FancyArrowPatch((sync_x, read_y + 0.8),
                        (write_x + write_width, write_y + 0.8),
                        arrowstyle='->', mutation_scale=20, 
                        linewidth=2, color=color_gray, zorder=1)
ax.add_patch(arrow4)

# Clock signals to synchronizer
# Write clock to synchronizer FF3, FF4
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

# Read clock to synchronizer FF1, FF2
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

# ========== Clock Waveform Illustration (Bottom) ==========
wave_y = 1.5
wave_height = 1.2

# Write clock waveform
wave_w_x_start = write_x + 0.5
wave_w_x_end = write_x + write_width - 0.5
wave_w_period = (wave_w_x_end - wave_w_x_start) / 2
wave_w_points = 100
wave_w_x = np.linspace(wave_w_x_start, wave_w_x_end, wave_w_points)
wave_w_y = wave_y + wave_height/2 + wave_height/4 * np.sign(np.sin(2 * np.pi * 2 * (wave_w_x - wave_w_x_start) / (wave_w_x_end - wave_w_x_start)))
ax.plot(wave_w_x, wave_w_y, color=color_clock, linewidth=2)
ax.text(wave_w_x_start + (wave_w_x_end - wave_w_x_start)/2, wave_y + wave_height + 0.1,
        'CLK_W (Same Freq, Out of Phase)', ha='center', va='bottom', fontsize=9, color=color_clock)

# Read clock waveform (phase offset)
wave_r_x_start = read_x + 0.5
wave_r_x_end = read_x + read_width - 0.5
wave_r_period = (wave_r_x_end - wave_r_x_start) / 2
wave_r_points = 100
wave_r_x = np.linspace(wave_r_x_start, wave_r_x_end, wave_r_points)
# Phase offset about 30 degrees
phase_offset = np.pi / 6
wave_r_y = wave_y + wave_height/2 + wave_height/4 * np.sign(np.sin(2 * np.pi * 2 * (wave_r_x - wave_r_x_start) / (wave_r_x_end - wave_r_x_start) + phase_offset))
ax.plot(wave_r_x, wave_r_y, color=color_clock, linewidth=2, linestyle='--')
ax.text(wave_r_x_start + (wave_r_x_end - wave_r_x_start)/2, wave_y + wave_height + 0.1,
        'CLK_R (Same Freq, Out of Phase)', ha='center', va='bottom', fontsize=9, color=color_clock)

# ========== Key Features Text ==========
info_text = """Key Features:
1. Gray Code encoding ensures only 1-bit changes per transition
2. Dual Flip-Flop Synchronizer (2-FF) eliminates metastability
3. Same frequency, out-of-phase clocks: Same freq but different phase
4. Write pointer synchronized to read domain, read pointer to write domain
5. Synchronized pointers used for empty/full detection
"""

ax.text(8, 0.3, info_text, ha='center', va='bottom', fontsize=9,
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.8))

# Title
ax.text(8, 9.5, 'Asynchronous FIFO Pointer Synchronizer Schematic\n(Same Frequency, Out-of-Phase Clocks)', 
        ha='center', va='top', fontsize=16, weight='bold')

plt.tight_layout()
plt.savefig('/workspace/async_fifo_pointer_sync_diagram_en.png', dpi=300, bbox_inches='tight')
plt.savefig('/workspace/async_fifo_pointer_sync_diagram_en.pdf', bbox_inches='tight')
print("Diagram generated: async_fifo_pointer_sync_diagram_en.png and .pdf")
