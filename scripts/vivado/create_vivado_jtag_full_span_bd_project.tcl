set origin_dir [file normalize [file join [file dirname [info script]] ..]]
set vivado_dir [file join $origin_dir vivado]
set proj_dir   [file join $vivado_dir jfs]
set bd_name    jfs
set img_w      1
set img_h      $img_w
set scale      2
set pl_freq_mhz 25
set use_w8a12_full_streamed 0
set use_w8a10_full_streamed 0
set use_tinyspan_w8a8_base_equiv 0
set use_tinyspan_w8a8_base_equiv_serial 1
set w8a12_out_lanes 8
set w8a12_tap_lanes 16
set w8a12_scale_lanes 2
if {[info exists ::env(JTAG_FULL_SPAN_IMG_W)]} {
  set img_w $::env(JTAG_FULL_SPAN_IMG_W)
  set img_h $img_w
}
if {[info exists ::env(JTAG_FULL_SPAN_IMG_H)]} {
  set img_h $::env(JTAG_FULL_SPAN_IMG_H)
}
if {[info exists ::env(JTAG_FULL_SPAN_SCALE)]} {
  set scale $::env(JTAG_FULL_SPAN_SCALE)
}
if {[info exists ::env(JTAG_FULL_SPAN_PL_FREQ_MHZ)]} {
  set pl_freq_mhz $::env(JTAG_FULL_SPAN_PL_FREQ_MHZ)
}
if {[info exists ::env(JTAG_FULL_SPAN_USE_W8A12)]} {
  set use_w8a12_full_streamed $::env(JTAG_FULL_SPAN_USE_W8A12)
}
if {[info exists ::env(JTAG_FULL_SPAN_USE_W8A10)]} {
  set use_w8a10_full_streamed $::env(JTAG_FULL_SPAN_USE_W8A10)
}
if {[info exists ::env(JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV)]} {
  set use_tinyspan_w8a8_base_equiv $::env(JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV)
}
if {[info exists ::env(JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL)]} {
  set use_tinyspan_w8a8_base_equiv_serial $::env(JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL)
}
if {($use_w8a12_full_streamed + $use_w8a10_full_streamed + $use_tinyspan_w8a8_base_equiv) > 1} {
  error "JTAG_FULL_SPAN_USE_W8A12, JTAG_FULL_SPAN_USE_W8A10, and JTAG_FULL_SPAN_USE_TINYSPAN_W8A8_BASE_EQUIV are mutually exclusive"
}
if {[info exists ::env(JTAG_FULL_SPAN_W8A12_OUT_LANES)]} {
  set w8a12_out_lanes $::env(JTAG_FULL_SPAN_W8A12_OUT_LANES)
}
if {[info exists ::env(JTAG_FULL_SPAN_W8A12_TAP_LANES)]} {
  set w8a12_tap_lanes $::env(JTAG_FULL_SPAN_W8A12_TAP_LANES)
}
if {[info exists ::env(JTAG_FULL_SPAN_W8A12_SCALE_LANES)]} {
  set w8a12_scale_lanes $::env(JTAG_FULL_SPAN_W8A12_SCALE_LANES)
}

file mkdir $vivado_dir
file mkdir [file join $vivado_dir logs]
file delete -force $proj_dir

create_project jfs $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

if {$use_w8a12_full_streamed} {
  # Keep the W8A12 JTAG project focused. Reading every rtl/span/*.v file pulls
  # in many unrelated probes and legacy engines, which can exhaust this host
  # before the actual W8A12 synthesis run starts.
  set rtl_sources [list \
      [file join $origin_dir rtl board sr_sd_axi_lite_accel.v] \
      [file join $origin_dir rtl board sr_jtag_rgb_transfer_endpoint.v] \
      [file join $origin_dir rtl span span_rgb_line_window3x3.v] \
      [file join $origin_dir rtl span span_w8a12_rgb_normalize.v] \
      [file join $origin_dir rtl span span_w8a12_rgb_window_normalize.v] \
      [file join $origin_dir rtl span span_w8a12_feature_line_window3x3.v] \
      [file join $origin_dir rtl span span_w8a12_weight_group_rom.v] \
      [file join $origin_dir rtl span span_w8a12_requant_pipe.v] \
      [file join $origin_dir rtl span span_w8a12_parallel_mac_tile.v] \
      [file join $origin_dir rtl span span_w8a12_parallel_group_accum_engine.v] \
      [file join $origin_dir rtl span span_w8a12_parallel_conv_vector_streamed_weights.v] \
    [file join $origin_dir rtl span span_w8a12_feature_conv_streamed_frontend.v] \
    [file join $origin_dir rtl span span_w8a12_unary_lut.v] \
    [file join $origin_dir rtl span span_w8a12_unary_lut_vector_stage.v] \
    [file join $origin_dir rtl span span_w8a12_attention.v] \
      [file join $origin_dir rtl span span_w8a12_conv1_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_spab_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_block1_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_block2_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_block3_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_block4_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_block5_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_block6_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_conv1_spab6_taps_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_conv2_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_conv_cat_scale_concat.v] \
      [file join $origin_dir rtl span span_w8a12_conv1x1_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_upsampler0_streamed_frontend.v] \
      [file join $origin_dir rtl span span_w8a12_pixelshuffle_x4_streamed_rgb.v] \
      [file join $origin_dir rtl span span_w8a12_upsampler0_pixelshuffle_streamed_rgb.v] \
      [file join $origin_dir rtl span span_w8a12_tail_streamed_rgb.v] \
      [file join $origin_dir rtl span span_w8a12_full_streamed_rgb.v] \
      [file join $origin_dir rtl span span_w8a12_full_streamed_rgb_axis.v] \
      [file join $origin_dir rtl generated tinyspan_model_config.vh] \
      [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 span_w8a12_layers.vh] \
      [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 span_w8a12_rgb_norm.vh] \
      [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 postprocess span_w8a12_postprocess.vh] \
  ]
} elseif {$use_w8a10_full_streamed} {
  # W8A10 board-path candidate shell. This is intentionally focused so the
  # first W8A10 board plumbing build does not pull unrelated experimental RTL.
  set rtl_sources [list \
      [file join $origin_dir rtl board sr_sd_axi_lite_accel.v] \
      [file join $origin_dir rtl board sr_jtag_rgb_transfer_endpoint.v] \
      [file join $origin_dir rtl span span_w8a10_full_streamed_rgb_axis.v] \
  ]
} elseif {$use_tinyspan_w8a8_base_equiv} {
  # Keep the TinySPAN board build focused on the acceptance core. The generic
  # SPAN glob brings in many unrelated experimental tops and can make Vivado
  # fail before synthesis starts on memory-constrained hosts.
  set rtl_sources [list \
      [file join $origin_dir rtl board sr_sd_axi_lite_accel.v] \
      [file join $origin_dir rtl board sr_jtag_rgb_transfer_endpoint.v] \
      [file join $origin_dir rtl span span_tinyspan_w8a8_bicubic_base_x4_streamed_serial.v] \
      [file join $origin_dir rtl span span_tinyspan_w8a8_base_add_equiv.v] \
      [file join $origin_dir rtl span span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v] \
      [file join $origin_dir rtl span span_tinyspan_w8a8_qrgb_to_rgb888.v] \
      [file join $origin_dir rtl span span_tinyspan_w8a8_full_streamed_rgb888_base_equiv.v] \
  ]
} else {
  set rtl_sources [concat \
      [glob -nocomplain [file join $origin_dir rtl span *.v]] \
      [glob -nocomplain [file join $origin_dir rtl pipeline *.v]] \
      [glob -nocomplain [file join $origin_dir rtl board *.v]] \
      [glob -nocomplain [file join $origin_dir rtl generated *.vh]] \
      [glob -nocomplain [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 *.vh]] \
      [glob -nocomplain [file join $origin_dir rtl generated reds_span_x4_f48_w8a12 postprocess *.vh]] \
      [glob -nocomplain [file join $origin_dir rtl generated official_span_x2 weights *.mem]] \
      [glob -nocomplain [file join $origin_dir rtl generated official_span_x4 weights *.mem]] \
  ]
}
add_files -fileset sources_1 $rtl_sources
set_property include_dirs [list [file join $origin_dir rtl] [file join $origin_dir rtl generated]] [get_filesets sources_1]
update_compile_order -fileset sources_1

create_bd_design $bd_name
current_bd_design $bd_name

# PS only provides PL clock/reset; image data is transferred by JTAG-to-AXI Master.
set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* ps]
set_property -dict [list \
  CONFIG.PSU__FPGA_PL0_ENABLE {1} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $pl_freq_mhz \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
  CONFIG.PSU__USE__FABRIC__RST {1} \
  CONFIG.PSU__USE__M_AXI_GP0 {0} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__M_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP0 {0} \
  CONFIG.PSU__USE__S_AXI_GP1 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP3 {0} \
  CONFIG.PSU__USE__S_AXI_GP4 {0} \
  CONFIG.PSU__USE__S_AXI_GP5 {0} \
  CONFIG.PSU__USE__S_AXI_GP6 {0} \
  CONFIG.PSU__USE__IRQ0 {0} \
] $ps

set jtag_axi [create_bd_cell -type ip -vlnv xilinx.com:ip:jtag_axi:* ja]
set axi_ic   [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* ai]
set rst      [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst]

set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $axi_ic

set sr [create_bd_cell -type module -reference sr_jtag_rgb_transfer_endpoint sr0]
set_property -dict [list \
  CONFIG.IMG_W $img_w \
  CONFIG.IMG_H $img_h \
  CONFIG.SCALE $scale \
  CONFIG.USE_FULL_OFFICIAL_SPAN {1} \
  CONFIG.USE_W8A12_FULL_STREAMED $use_w8a12_full_streamed \
  CONFIG.USE_W8A10_FULL_STREAMED $use_w8a10_full_streamed \
  CONFIG.USE_TINYSPAN_W8A8_BASE_EQUIV $use_tinyspan_w8a8_base_equiv \
  CONFIG.USE_TINYSPAN_W8A8_BASE_EQUIV_SERIAL $use_tinyspan_w8a8_base_equiv_serial \
  CONFIG.W8A12_OUT_LANES $w8a12_out_lanes \
  CONFIG.W8A12_TAP_LANES $w8a12_tap_lanes \
  CONFIG.W8A12_SCALE_LANES $w8a12_scale_lanes \
  CONFIG.VIDEO_GAIN_EN {0} \
] $sr

connect_bd_intf_net [get_bd_intf_pins ja/M_AXI] [get_bd_intf_pins ai/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ai/M00_AXI] [get_bd_intf_pins sr0/s_axi]

connect_bd_net [get_bd_pins ps/pl_clk0] \
  [get_bd_pins ja/aclk] \
  [get_bd_pins ai/ACLK] \
  [get_bd_pins ai/S00_ACLK] \
  [get_bd_pins ai/M00_ACLK] \
  [get_bd_pins rst/slowest_sync_clk] \
  [get_bd_pins sr0/s_axi_aclk]

connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
  [get_bd_pins ja/aresetn] \
  [get_bd_pins ai/S00_ARESETN] \
  [get_bd_pins ai/M00_ARESETN] \
  [get_bd_pins sr0/s_axi_aresetn]
connect_bd_net [get_bd_pins rst/interconnect_aresetn] [get_bd_pins ai/ARESETN]

assign_bd_address
set sr_seg [get_bd_addr_segs -quiet sr0/s_axi/*]
if {[llength $sr_seg] > 0} {
  assign_bd_address -offset 0xA0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces ja/Data] [lindex $sr_seg 0] -force
}

validate_bd_design
save_bd_design

set bd_file [get_files [file join $proj_dir jfs.srcs sources_1 bd $bd_name ${bd_name}.bd]]
catch { set_property synth_checkpoint_mode None $bd_file }
catch { set_property generate_synth_checkpoint false $bd_file }

make_wrapper -files [get_files [file join $proj_dir jfs.srcs sources_1 bd $bd_name ${bd_name}.bd]] -top
add_files -norecurse [file join $proj_dir jfs.gen sources_1 bd $bd_name hdl ${bd_name}_wrapper.v]
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "Created JTAG full official SPAN RGB transfer Block Design project:"
puts "  [file join $proj_dir jfs.xpr]"
puts ""
puts "Data path:"
puts "  USB-JTAG -> JTAG-to-AXI Master -> sr_jtag_rgb_transfer_endpoint -> SPAN pipeline"
puts ""
puts "JTAG AXI address for sr_jtag_rgb_transfer_endpoint:"
puts "  0xA0000000"
puts ""
puts "Full SPAN smoke image width:"
puts "  $img_w"
puts "Full SPAN smoke image height:"
puts "  $img_h"
puts "Full SPAN scale:"
puts "  X$scale"
puts "PL0 clock frequency MHz:"
puts "  $pl_freq_mhz"
puts "Use W8A12 full streamed core:"
puts "  $use_w8a12_full_streamed"
puts "Use W8A10 full streamed core:"
puts "  $use_w8a10_full_streamed"
puts "Use TinySPAN W8A8 base-equivalent core:"
puts "  $use_tinyspan_w8a8_base_equiv"
puts "Use TinySPAN W8A8 serial base generator:"
puts "  $use_tinyspan_w8a8_base_equiv_serial"
if {$use_w8a12_full_streamed} {
  puts "W8A12 output lanes:"
  puts "  $w8a12_out_lanes"
  puts "W8A12 tap lanes:"
  puts "  $w8a12_tap_lanes"
  puts "W8A12 scale lanes:"
  puts "  $w8a12_scale_lanes"
}
