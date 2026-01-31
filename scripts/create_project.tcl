# ============================================================================
# Vivado Project Recreation Script
# Project : QMF
# Board   : KV260 (Zynq UltraScale+)
# Scope   : RTL + BD recreation only (no bitstream)
# ============================================================================

set project_name QMF
set part_name xck26-sfvc784-2LV-c
set board_part xilinx.com:kv260_som:part0:1.4

# Root directory (repo root expected)
set origin_dir [file normalize "."]

# ----------------------------------------------------------------------------
# Create Project
# ----------------------------------------------------------------------------
create_project $project_name ./$project_name -part $part_name
set_property board_part $board_part [current_project]
set_property simulator_language Mixed [current_project]

# ----------------------------------------------------------------------------
# Add RTL Sources
# ----------------------------------------------------------------------------
add_files -fileset sources_1 [list \
    rtl/fir_core.v \
    rtl/gain_core.v \
    rtl/gain_axis_wrapper.v \
    rtl/qmf_analysis_core.v \
    rtl/qmf_analysis_axis.v \
    rtl/qmf_synthesis_core.v \
    rtl/qmf_synthesis_axis.v \
]

set_property top QMF_wrapper [get_filesets sources_1]

# ----------------------------------------------------------------------------
# Add Testbenches
# ----------------------------------------------------------------------------
add_files -fileset sim_1 [list \
    tb/tb_gain_axis_wrapper.sv \
    tb/tb_qmf_gain_system.sv \
    tb/tb_gain_synthesis_only.sv \
    tb/tb_analysis_gain_only.sv \
    tb/tb_qmf_axis.sv \
    tb/tb_qmf_system.sv \
]

set_property top tb_qmf_system [get_filesets sim_1]
set_property file_type SystemVerilog [get_filesets sim_1]

# ----------------------------------------------------------------------------
# Block Design Creation
# ----------------------------------------------------------------------------
proc cr_bd_QMF {} {

    create_bd_design QMF

    # Processing System
    set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]

    # AXI DMA
    set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma]
    set_property CONFIG.c_include_sg 0 $dma

    # Reset
    set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst]

    # Custom RTL Blocks
    create_bd_cell -type module -reference qmf_analysis_axis qmf_analysis
    create_bd_cell -type module -reference qmf_synthesis_axis qmf_synthesis
    create_bd_cell -type module -reference gain_axis_wrapper gain_high
    create_bd_cell -type module -reference gain_axis_wrapper gain_low

    # AXI Connections (intentionally concise)
    connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S] [get_bd_intf_pins qmf_analysis/s_axis]
    connect_bd_intf_net [get_bd_intf_pins qmf_analysis/m_axis_high] [get_bd_intf_pins gain_high/s_axis]
    connect_bd_intf_net [get_bd_intf_pins qmf_analysis/m_axis_low]  [get_bd_intf_pins gain_low/s_axis]
    connect_bd_intf_net [get_bd_intf_pins gain_high/m_axis] [get_bd_intf_pins qmf_synthesis/s_axis_high]
    connect_bd_intf_net [get_bd_intf_pins gain_low/m_axis]  [get_bd_intf_pins qmf_synthesis/s_axis_low]
    connect_bd_intf_net [get_bd_intf_pins qmf_synthesis/m_axis] [get_bd_intf_pins dma/S_AXIS_S2MM]

    validate_bd_design
    save_bd_design
}

cr_bd_QMF

# ----------------------------------------------------------------------------
# Generate Wrapper
# ----------------------------------------------------------------------------
make_wrapper -files [get_files QMF.bd] -top
add_files -fileset sources_1 QMF_wrapper.v

# ----------------------------------------------------------------------------
# Create Runs (No auto-launch)
# ----------------------------------------------------------------------------
create_run synth_1 -flow {Vivado Synthesis 2024} -part $part_name
create_run impl_1  -flow {Vivado Implementation 2024} -part $part_name -parent_run synth_1

puts "INFO: QMF project successfully recreated (RTL + BD only)"
