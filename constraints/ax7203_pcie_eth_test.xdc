####################################################################################
## PCIe + Ethernet Clock Test Constraints
## AX7203 (XC7A200T-2FBG484I)
##
## Test: Add Ethernet clock domain to working Project 22 PCIe
## If PCIe breaks, investigate clock interaction or reset sequencing
####################################################################################

####################################################################################
## System Configuration
####################################################################################
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

####################################################################################
## System Clock (200 MHz Differential) - From Ethernet Oscillator
####################################################################################
#create_clock -period 5.000 -name sys_clk_p [get_ports sys_clk_p]
#set_property PACKAGE_PIN R4 [get_ports sys_clk_p]
#set_property PACKAGE_PIN T4 [get_ports sys_clk_n]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_p]
#set_property IOSTANDARD DIFF_SSTL15 [get_ports sys_clk_n]

####################################################################################
## PCIe Reference Clock (100 MHz Differential)
####################################################################################
set_property PACKAGE_PIN F10 [get_ports {pcie_refclk_clk_p[0]}]
set_property PACKAGE_PIN E10 [get_ports {pcie_refclk_clk_n[0]}]
create_clock -period 10.000 -name pcie_refclk [get_ports {pcie_refclk_clk_p[0]}]

####################################################################################
## Reset Signals
####################################################################################

## PCIe PERST# (Active Low)
set_property PACKAGE_PIN J20 [get_ports pcie_perst_n]
set_property IOSTANDARD LVCMOS33 [get_ports pcie_perst_n]
set_property PULLUP TRUE [get_ports pcie_perst_n]
set_false_path -from [get_ports pcie_perst_n]

## System Reset Button (active LOW)
set_property PACKAGE_PIN T6 [get_ports reset_n]
set_property IOSTANDARD LVCMOS15 [get_ports reset_n]
set_false_path -from [get_ports reset_n]

####################################################################################
## LEDs (4 Red LEDs)
####################################################################################
set_property PACKAGE_PIN B13 [get_ports {led[0]}]
set_property PACKAGE_PIN C13 [get_ports {led[1]}]
set_property PACKAGE_PIN D14 [get_ports {led[2]}]
set_property PACKAGE_PIN D15 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
set_false_path -to [get_ports {led[*]}]

####################################################################################
## RGMII Ethernet Port 1 - Clock Only (no data path)
####################################################################################

## RGMII RX Clock (125 MHz from PHY)
create_clock -period 8.000 [get_ports rgmii1_rxc]
set_property PACKAGE_PIN B17 [get_ports rgmii1_rxc]
set_property IOSTANDARD LVCMOS33 [get_ports rgmii1_rxc]

## RGMII TX Interface (drive idle)
set_property PACKAGE_PIN E18 [get_ports rgmii1_txc]
set_property IOSTANDARD LVCMOS33 [get_ports rgmii1_txc]

set_property PACKAGE_PIN F18 [get_ports rgmii1_txctl]
set_property IOSTANDARD LVCMOS33 [get_ports rgmii1_txctl]

set_property PACKAGE_PIN C20 [get_ports {rgmii1_txd[0]}]
set_property PACKAGE_PIN D20 [get_ports {rgmii1_txd[1]}]
set_property PACKAGE_PIN A19 [get_ports {rgmii1_txd[2]}]
set_property PACKAGE_PIN A18 [get_ports {rgmii1_txd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {rgmii1_txd[*]}]

## PHY Reset
set_property PACKAGE_PIN D16 [get_ports e1_reset]
set_property IOSTANDARD LVCMOS33 [get_ports e1_reset]

####################################################################################
## PCIe GTP Transceiver Lanes (Gen1 x4)
## AX7203 lane ordering: Lane0=X0Y5, Lane1=X0Y4, Lane2=X0Y6, Lane3=X0Y7
####################################################################################

set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
set_property LOC GTPE2_CHANNEL_X0Y4 [get_cells -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_lane[1].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_lane[2].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
set_property LOC GTPE2_CHANNEL_X0Y7 [get_cells -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_lane[3].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

set_property LOC GTPE2_COMMON_X0Y1 [get_cells -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].pipe_quad.gt_common_enabled.gt_common_int.gt_common_i/qpll_wrapper_i/gtp_common.gtpe2_common_i}]

set_property LOC PCIE_X0Y0 [get_cells -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/pcie_top_i/pcie_7x_i/pcie_block_i}]

## Suppress DRC for MGT ports
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
create_waiver -quiet -type DRC -id {UCIO-1} -description {PCIe MGT ports constrained by GTPE2_CHANNEL LOC} \
    -objects [get_ports -quiet {pcie_mgt_txp[*] pcie_mgt_txn[*] pcie_mgt_rxp[*] pcie_mgt_rxn[*]}]

####################################################################################
## Clock Groups (Asynchronous Domains)
####################################################################################

## All clocks are asynchronous to each other
#set_clock_groups -asynchronous \
#    -group [get_clocks sys_clk_p] \
#    -group [get_clocks rgmii1_rxc] \
#    -group [get_clocks -include_generated_clocks pcie_refclk]
set_clock_groups -asynchronous \
    -group [get_clocks rgmii1_rxc] \
    -group [get_clocks -include_generated_clocks pcie_refclk]
####################################################################################
## PCIe Timing Constraints
####################################################################################

## PCIe TXOUTCLK
## PCIe TXOUTCLK (multiple patterns for different XDMA wrapper naming)
## Pattern 1: Explicit path matching actual design hierarchy (U0/inst format)
create_clock -period 10.000 -name txoutclk_x0y0 [get_pins -quiet {pcie_system_inst/pcie_system_i/xdma_0/inst/pcie_system_xdma_0_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i/TXOUTCLK}]
## Pattern 2: Wildcard path with U0/inst
create_clock -period 10.000 -name txoutclk_x0y0 [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i/TXOUTCLK}]
## Pattern 3: Wildcard path with inst/inst (older format)
create_clock -period 10.000 -name txoutclk_x0y0 [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i/TXOUTCLK}]

## PCIe MMCM generated clocks
create_generated_clock -quiet -name clk_125mhz_x0y0 [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT0}]
create_generated_clock -quiet -name clk_250mhz_x0y0 [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT1}]

## PCIe clock mux
create_generated_clock -quiet -name clk_125mhz_mux_x0y0 \
    -source [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I0}] \
    -divide_by 1 \
    [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}]

create_generated_clock -quiet -name clk_250mhz_mux_x0y0 \
    -source [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1}] \
    -divide_by 1 -add -master_clock clk_250mhz_x0y0 \
    [get_pins -quiet {*/xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O}]

set_clock_groups -quiet -physically_exclusive \
    -group [get_clocks -quiet clk_125mhz_mux_x0y0] \
    -group [get_clocks -quiet clk_250mhz_mux_x0y0]

set_clock_groups -quiet -physically_exclusive \
    -group [get_clocks -quiet clk_125mhz_x0y0] \
    -group [get_clocks -quiet clk_250mhz_x0y0]

## PCIe PIPE clock mux false paths
set_false_path -quiet -to [get_pins -quiet {*xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}]
set_false_path -quiet -to [get_pins -quiet {*xdma_0/inst/*pcie2_to_pcie3_wrapper_i/pcie2_ip_i/*/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1}]
set_false_path -quiet -from [get_cells -quiet -hierarchical -filter {NAME =~ *pipe_clock_i/pclk_sel_reg*}]

## PCIe async signals
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~PLPHYLNKUPN} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ *}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~PLRECEIVEDHOTRST} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ *}]]

## GTP transceiver async signals
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~RXELECIDLE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~TXPHINITDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~TXPHALIGNDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~TXDLYSRESETDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~RXDLYSRESETDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~RXPHALIGNDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~RXCDRLOCK} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~CFGMSGRECEIVEDPMETO} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ *}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~PLL0LOCK} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~RXPMARESETDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~RXSYNCDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]
set_false_path -through [get_pins -quiet -filter {REF_PIN_NAME=~TXSYNCDONE} -of_objects [get_cells -quiet -hierarchical -filter {PRIMITIVE_TYPE =~ IO.gt.*}]]

####################################################################################
