#=============================================================================
# Synthesis Script for AES256-CTR Engine
# Target: Generic FPGA/ASIC (adjustable)
#=============================================================================

# Set project variables
set TOP_MODULE "aes256_ctr_top"
set CLOCK_NAME "clk"
set CLOCK_PERIOD 5.0  # 200 MHz default (adjustable)

# Read design files
read_file -format verilog {rtl/aes256_ctr_top.sv}
read_file -format verilog {rtl/aes256_core.sv}
read_file -format verilog {rtl/ctr_mode_engine.sv}
read_file -format verilog {rtl/key_manager.sv}
read_file -format verilog {rtl/axi_stream_interface.sv}
read_file -format verilog {rtl/apb_interface.sv}

# Elaborate top module
elaborate $TOP_MODULE

# Set top module
current_design $TOP_MODULE

# Create clocks
create_clock -name $CLOCK_NAME -period $CLOCK_PERIOD [get_ports clk]
set_dont_touch_network [get_clocks $CLOCK_NAME]

# Set clock uncertainty
set_clock_uncertainty -setup 0.1 [get_clocks $CLOCK_NAME]
set_clock_uncertainty -hold 0.05 [get_clocks $CLOCK_NAME]

# Set input/output delays
set_input_delay -clock $CLOCK_NAME -max 1.0 [all_inputs]
set_input_delay -clock $CLOCK_NAME -min 0.5 [all_inputs]
set_output_delay -clock $CLOCK_NAME -max 1.0 [all_outputs]
set_output_delay -clock $CLOCK_NAME -min 0.5 [all_outputs]

# Remove clock from input/output delay
remove_input_delay [get_ports clk]
remove_output_delay [get_ports clk]

# Set false paths (if any)
# Example: set_false_path -from [get_ports rst_n] -to [all_registers]

# Set multicycle paths (if any)
# Example for key expansion if needed

# Set maximum fanout
set_max_fanout 32 $TOP_MODULE

# Set maximum transition
set_max_transition 0.5 $TOP_MODULE

# Compile
compile_ultra

# Report timing
report_timing -max_paths 20 -delay_type max > reports/timing_max.rpt
report_timing -max_paths 20 -delay_type min > reports/timing_min.rpt

# Report area
report_area > reports/area.rpt
report_cell > reports/cell.rpt

# Report power (if available)
# report_power > reports/power.rpt

# Report constraints
report_constraints -all_violators > reports/constraints.rpt

# Write netlist
write -format verilog -hierarchy -output netlists/${TOP_MODULE}_syn.v
write -format ddc -hierarchy -output netlists/${TOP_MODULE}_syn.ddc

# Write SDC
write_sdc outputs/${TOP_MODULE}.sdc

puts "Synthesis completed. Check reports/ directory for results."
