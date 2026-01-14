###################################################################################
## PCIe + Ethernet Clock Test Build Script
## Purpose: Test if adding Ethernet clock domain breaks PCIe detection
##
## This is Project 22 (working Gen2 PCIe) with ONLY Ethernet clock domain added.
## NO data path - just test if clock domains can coexist.
##
## Target: AX7203 (XC7A200T-2FBG484I)
###################################################################################

set project_name "22-order-book-pcie-eth-test"
set project_dir "./vivado_project"
set part_name "xc7a200tfbg484-2"
set_param general.maxThreads 16

# Create project
create_project $project_name $project_dir -part $part_name -force

set_property target_language VHDL [current_project]
set_property simulator_language Mixed [current_project]

###################################################################################
## Add RTL Source Files
###################################################################################
puts "Adding RTL source files..."
add_files -norecurse src/pcie_eth_test_top.vhd
update_compile_order -fileset sources_1

###################################################################################
## Create Block Design (PCIe only - same as Project 22)
###################################################################################
create_bd_design "pcie_system"

# Add XDMA IP
create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.2 xdma_0

# Configure XDMA for Gen1 x4 at 125 MHz (known working configuration)
set_property -dict [list \
    CONFIG.pcie_blk_locn {X0Y0} \
    CONFIG.select_quad {GTH_Quad_128} \
    CONFIG.pl_link_cap_max_link_width {X4} \
    CONFIG.pl_link_cap_max_link_speed {5.0_GT/s} \
    CONFIG.axi_data_width {64_bit} \
    CONFIG.axisten_freq {250} \
    CONFIG.pf0_device_id {7024} \
    CONFIG.pf0_subsystem_id {0007} \
    CONFIG.pf0_subsystem_vendor_id {10EE} \
    CONFIG.pf0_class_code_base {05} \
    CONFIG.pf0_class_code_sub {80} \
    CONFIG.pf0_class_code_interface {00} \
    CONFIG.xdma_num_usr_irq {4} \
    CONFIG.pf0_msi_enabled {true} \
    CONFIG.pf0_msix_enabled {false} \
    CONFIG.cfg_mgmt_if {false} \
    CONFIG.plltype {QPLL1} \
    CONFIG.dma_reset_source_sel {User_Reset} \
    CONFIG.en_gt_selection {true} \
    CONFIG.mode_selection {Advanced} \
    CONFIG.pcie_extended_tag {true} \
    CONFIG.c_s_axi_supports_narrow_burst {false} \
    CONFIG.xdma_axi_intf_mm {AXI_Stream} \
    CONFIG.xdma_rnum_chnl {1} \
    CONFIG.xdma_wnum_chnl {1} \
    CONFIG.axilite_master_en {false} \
    CONFIG.axisten_if_enable_client_tag {false} \
    CONFIG.xdma_sts_ports {false} \
    CONFIG.pf0_bar0_enabled {true} \
    CONFIG.pf0_bar0_type {Memory} \
    CONFIG.pf0_bar0_64bit {false} \
    CONFIG.pf0_bar0_prefetchable {false} \
    CONFIG.pf0_bar0_scale {Kilobytes} \
    CONFIG.pf0_bar0_size {128} \
] [get_bd_cells xdma_0]

###################################################################################
## External Ports
###################################################################################

# PCIe MGT
create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pcie_mgt
connect_bd_intf_net [get_bd_intf_pins xdma_0/pcie_mgt] [get_bd_intf_ports pcie_mgt]

# PCIe clock
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk
create_bd_port -dir I -type rst reset_rtl_0
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports reset_rtl_0]

# Differential buffer for PCIe reference clock
create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0
set_property CONFIG.C_BUF_TYPE {IBUFDSGTE} [get_bd_cells util_ds_buf_0]
connect_bd_intf_net [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
connect_bd_net [get_bd_pins util_ds_buf_0/IBUF_OUT] [get_bd_pins xdma_0/sys_clk]
connect_bd_net [get_bd_ports reset_rtl_0] [get_bd_pins xdma_0/sys_rst_n]

# S_AXIS_C2H external ports
create_bd_port -dir I -from 63 -to 0 s_axis_c2h_tdata
create_bd_port -dir I -from 7 -to 0 s_axis_c2h_tkeep
create_bd_port -dir I s_axis_c2h_tvalid
create_bd_port -dir O s_axis_c2h_tready
create_bd_port -dir I s_axis_c2h_tlast

connect_bd_net [get_bd_ports s_axis_c2h_tdata] [get_bd_pins xdma_0/s_axis_c2h_tdata_0]
connect_bd_net [get_bd_ports s_axis_c2h_tkeep] [get_bd_pins xdma_0/s_axis_c2h_tkeep_0]
connect_bd_net [get_bd_ports s_axis_c2h_tvalid] [get_bd_pins xdma_0/s_axis_c2h_tvalid_0]
connect_bd_net [get_bd_pins xdma_0/s_axis_c2h_tready_0] [get_bd_ports s_axis_c2h_tready]
connect_bd_net [get_bd_ports s_axis_c2h_tlast] [get_bd_pins xdma_0/s_axis_c2h_tlast_0]

# AXI clock and reset outputs
create_bd_port -dir O axi_aclk
create_bd_port -dir O axi_aresetn
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_ports axi_aclk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_ports axi_aresetn]

# Tie off H2C
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_h2c_tready
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {1}] [get_bd_cells const_h2c_tready]
connect_bd_net [get_bd_pins const_h2c_tready/dout] [get_bd_pins xdma_0/m_axis_h2c_tready_0]

# Reset infrastructure
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_xdma
connect_bd_net [get_bd_pins xdma_0/axi_aclk] [get_bd_pins rst_xdma/slowest_sync_clk]
connect_bd_net [get_bd_pins xdma_0/axi_aresetn] [get_bd_pins rst_xdma/ext_reset_in]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_one
set_property -dict [list CONFIG.CONST_WIDTH {1} CONFIG.CONST_VAL {1}] [get_bd_cells const_one]
connect_bd_net [get_bd_pins const_one/dout] [get_bd_pins rst_xdma/dcm_locked]

# Tie off user interrupts
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 const_zero_4
set_property -dict [list CONFIG.CONST_WIDTH {4} CONFIG.CONST_VAL {0}] [get_bd_cells const_zero_4]
connect_bd_net [get_bd_pins const_zero_4/dout] [get_bd_pins xdma_0/usr_irq_req]

# Link up status
create_bd_port -dir O user_lnk_up
connect_bd_net [get_bd_pins xdma_0/user_lnk_up] [get_bd_ports user_lnk_up]

###################################################################################
## Finalize Block Design
###################################################################################
assign_bd_address
regenerate_bd_layout
validate_bd_design
save_bd_design

upgrade_project -migrate_to_inline_hdl

make_wrapper -files [get_files $project_dir/$project_name.srcs/sources_1/bd/pcie_system/pcie_system.bd] -top
add_files -norecurse $project_dir/$project_name.gen/sources_1/bd/pcie_system/hdl/pcie_system_wrapper.vhd

set_property top pcie_eth_test_top [current_fileset]
puts "Set pcie_eth_test_top as top module"

###################################################################################
## Constraints
###################################################################################
add_files -fileset constrs_1 -norecurse constraints/ax7203_pcie_eth_test.xdc

generate_target all [get_files $project_dir/$project_name.srcs/sources_1/bd/pcie_system/pcie_system.bd]

# Disable auto-generated GTP constraints
set auto_gen_xdc [get_files -quiet *pcie2_ip-PCIE_X0Y0.xdc]
if {[llength $auto_gen_xdc] > 0} {
    puts "Disabling auto-generated GTP constraint file: $auto_gen_xdc"
    set_property IS_ENABLED false [get_files $auto_gen_xdc]
    set_property USED_IN {} [get_files $auto_gen_xdc]
}

set xdma_xdc_files [get_files -quiet -of_objects [get_ips -quiet *xdma*] *.xdc]
foreach xdc_file $xdma_xdc_files {
    set file_name [get_property NAME $xdc_file]
    if {[string match "*PCIE_X0Y0*" $file_name] || [string match "*pcie2_ip*" $file_name]} {
        puts "Disabling XDMA IP constraint file: $xdc_file"
        set_property IS_ENABLED false $xdc_file
        set_property USED_IN {} $xdc_file
    }
}

set_property PROCESSING_ORDER LATE [get_files constraints/ax7203_pcie_eth_test.xdc]

###################################################################################
## Implementation Settings
###################################################################################
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE ExtraTimingOpt [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

###################################################################################
## Build
###################################################################################
puts "Starting synthesis..."
launch_runs synth_1 -jobs 16
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    puts "ERROR: Synthesis failed!"
    return
}
puts "Synthesis completed."

puts "Starting implementation..."
launch_runs impl_1 -jobs 16
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    puts "ERROR: Implementation failed!"
    return
}
puts "Implementation completed."

puts "Generating bitstream..."
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

puts ""
puts "=============================================="
puts "Build completed!"
puts "Bitstream: vivado_project/*/impl_1/*.bit"
puts ""
puts "TEST: Load this bitstream and check if PCIe"
puts "      card is detected. If yes, clock domains"
puts "      can coexist. If no, investigate reset"
puts "      sequencing or clock interaction."
puts "=============================================="
