# ============================================================================
# Block Design Tcl (Minimal & Portable)
# Design : QMF
# Board  : KV260 (Zynq UltraScale+)
# Scope  : Connectivity + address map only
# ============================================================================

set design_name QMF
create_bd_design $design_name

# ----------------------------------------------------------------------------
# Processing System
# ----------------------------------------------------------------------------
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.5 ps]

# Enable basic AXI interfaces only
set_property -dict [list \
  CONFIG.PSU__USE__M_AXI_GP0 {1} \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__USE__S_AXI_GP3 {1} \
  CONFIG.PSU__FPGA_PL0_ENABLE {1} \
] $ps

# ----------------------------------------------------------------------------
# AXI DMA
# ----------------------------------------------------------------------------
set dma [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma]
set_property CONFIG.c_include_sg {0} $dma

# ----------------------------------------------------------------------------
# Reset
# ----------------------------------------------------------------------------
set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst]

# ----------------------------------------------------------------------------
# AXI Interconnects
# ----------------------------------------------------------------------------
set axi_ctrl [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_ctrl]
set_property CONFIG.NUM_MI {5} $axi_ctrl

set axi_mm2s [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_mm2s]
set_property CONFIG.NUM_SI {1} $axi_mm2s

set axi_s2mm [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_s2mm]
set_property CONFIG.NUM_SI {1} $axi_s2mm

# ----------------------------------------------------------------------------
# Custom RTL Blocks
# ----------------------------------------------------------------------------
create_bd_cell -type module -reference qmf_analysis_axis  qmf_analysis
create_bd_cell -type module -reference qmf_synthesis_axis qmf_synthesis
create_bd_cell -type module -reference gain_axis_wrapper  gain_high
create_bd_cell -type module -reference gain_axis_wrapper  gain_low

# ----------------------------------------------------------------------------
# AXI-Stream Data Path
# ----------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins dma/M_AXIS_MM2S] \
                    [get_bd_intf_pins qmf_analysis/s_axis]

connect_bd_intf_net [get_bd_intf_pins qmf_analysis/m_axis_high] \
                    [get_bd_intf_pins gain_high/s_axis]

connect_bd_intf_net [get_bd_intf_pins qmf_analysis/m_axis_low] \
                    [get_bd_intf_pins gain_low/s_axis]

connect_bd_intf_net [get_bd_intf_pins gain_high/m_axis] \
                    [get_bd_intf_pins qmf_synthesis/s_axis_high]

connect_bd_intf_net [get_bd_intf_pins gain_low/m_axis] \
                    [get_bd_intf_pins qmf_synthesis/s_axis_low]

connect_bd_intf_net [get_bd_intf_pins qmf_synthesis/m_axis] \
                    [get_bd_intf_pins dma/S_AXIS_S2MM]

# ----------------------------------------------------------------------------
# AXI-Lite Control Path
# ----------------------------------------------------------------------------
connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] \
                    [get_bd_intf_pins axi_ctrl/S00_AXI]

connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M00_AXI] \
                    [get_bd_intf_pins dma/S_AXI_LITE]

connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M01_AXI] \
                    [get_bd_intf_pins qmf_analysis/s_axi]

connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M02_AXI] \
                    [get_bd_intf_pins qmf_synthesis/s_axi]

connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M03_AXI] \
                    [get_bd_intf_pins gain_high/s_axi]

connect_bd_intf_net [get_bd_intf_pins axi_ctrl/M04_AXI] \
                    [get_bd_intf_pins gain_low/s_axi]

# ----------------------------------------------------------------------------
# Clock & Reset
# ----------------------------------------------------------------------------
connect_bd_net [get_bd_pins ps/pl_clk0] \
               [get_bd_pins dma/m_axi_mm2s_aclk] \
               [get_bd_pins dma/m_axi_s2mm_aclk] \
               [get_bd_pins dma/s_axi_lite_aclk] \
               [get_bd_pins axi_ctrl/ACLK] \
               [get_bd_pins axi_mm2s/aclk] \
               [get_bd_pins axi_s2mm/aclk] \
               [get_bd_pins qmf_analysis/clk] \
               [get_bd_pins qmf_synthesis/clk] \
               [get_bd_pins gain_high/aclk] \
               [get_bd_pins gain_low/aclk]

connect_bd_net [get_bd_pins ps/pl_resetn0] \
               [get_bd_pins rst/ext_reset_in]

connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
               [get_bd_pins dma/axi_resetn] \
               [get_bd_pins qmf_analysis/rstn] \
               [get_bd_pins qmf_synthesis/rstn] \
               [get_bd_pins gain_high/aresetn] \
               [get_bd_pins gain_low/aresetn]

# ----------------------------------------------------------------------------
# Address Map (Simple & Deterministic)
# ----------------------------------------------------------------------------
assign_bd_address -offset 0xA0000000 -range 0x00010000 \
  [get_bd_addr_segs dma/S_AXI_LITE/Reg]

assign_bd_address -offset 0xA0010000 -range 0x00001000 \
  [get_bd_addr_segs qmf_analysis/s_axi/reg0]

assign_bd_address -offset 0xA0011000 -range 0x00001000 \
  [get_bd_addr_segs qmf_synthesis/s_axi/reg0]

assign_bd_address -offset 0xA0012000 -range 0x00001000 \
  [get_bd_addr_segs gain_high/s_axi/reg0]

assign_bd_address -offset 0xA0013000 -range 0x00001000 \
  [get_bd_addr_segs gain_low/s_axi/reg0]

# ----------------------------------------------------------------------------
# Finalize
# ----------------------------------------------------------------------------
validate_bd_design
save_bd_design

puts "INFO: QMF block design created (minimal, connectivity-focused)"
