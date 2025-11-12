#!/bin/bash
# Simulation script for CRC Accelerator

# Set simulation tool (modify as needed)
SIM_TOOL=${SIM_TOOL:-vcs}  # Options: vcs, xcelium, questa, iverilog

# Create work directory
mkdir -p work
mkdir -p logs

echo "=========================================="
echo "CRC Accelerator Simulation"
echo "Simulation Tool: $SIM_TOOL"
echo "=========================================="

case $SIM_TOOL in
    vcs)
        # Synopsys VCS
        vcs -full64 -sverilog \
            -timescale=1ns/1ps \
            -debug_access+all \
            +incdir+../rtl \
            ../rtl/*.v \
            ../tb/*.v \
            -top crc_accelerator_tb \
            -o simv \
            -l logs/vcs.log
        ./simv -l logs/sim.log
        ;;
    
    xcelium)
        # Cadence Xcelium
        xrun -64bit -sv \
            -timescale 1ns/1ps \
            -incdir ../rtl \
            ../rtl/*.v \
            ../tb/*.v \
            -top crc_accelerator_tb \
            -l logs/xcelium.log
        ;;
    
    questa)
        # Mentor Questa
        vlog -work work -sv \
            -timescale 1ns/1ps \
            +incdir+../rtl \
            ../rtl/*.v \
            ../tb/*.v \
            -l logs/compile.log
        vsim -c -do "run -all; quit" work.crc_accelerator_tb -l logs/sim.log
        ;;
    
    iverilog)
        # Icarus Verilog
        iverilog -g2012 \
            -I ../rtl \
            -o simv \
            ../rtl/*.v \
            ../tb/*.v \
            -l logs/compile.log
        vvp simv -l logs/sim.log
        ;;
    
    *)
        echo "Unknown simulation tool: $SIM_TOOL"
        echo "Supported tools: vcs, xcelium, questa, iverilog"
        exit 1
        ;;
esac

echo "=========================================="
echo "Simulation completed. Check logs/ for results."
echo "=========================================="
