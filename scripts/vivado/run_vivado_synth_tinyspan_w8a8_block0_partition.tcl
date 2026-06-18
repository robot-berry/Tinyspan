set origin_dir [file normalize [file join [file dirname [info script]] ..]]

if {![info exists ::env(TINYSPAN_BLOCK0_PARTITION_TOP)]} {
    error "TINYSPAN_BLOCK0_PARTITION_TOP is required"
}
if {![info exists ::env(TINYSPAN_BLOCK0_PARTITION_TAG)]} {
    set ::env(TINYSPAN_BLOCK0_PARTITION_TAG) $::env(TINYSPAN_BLOCK0_PARTITION_TOP)
}
if {![info exists ::env(TINYSPAN_BLOCK0_PARTITION_CLOCK_PERIOD_NS)]} {
    set ::env(TINYSPAN_BLOCK0_PARTITION_CLOCK_PERIOD_NS) "10.000"
}
if {![info exists ::env(TINYSPAN_BLOCK0_PARTITION_IMG_W)]} {
    set ::env(TINYSPAN_BLOCK0_PARTITION_IMG_W) "4"
}
if {![info exists ::env(TINYSPAN_BLOCK0_PARTITION_IMG_H)]} {
    set ::env(TINYSPAN_BLOCK0_PARTITION_IMG_H) $::env(TINYSPAN_BLOCK0_PARTITION_IMG_W)
}
if {![info exists ::env(TINYSPAN_BLOCK0_PARTITION_OUT_LANES)]} {
    set ::env(TINYSPAN_BLOCK0_PARTITION_OUT_LANES) "8"
}
if {![info exists ::env(TINYSPAN_BLOCK0_PARTITION_TAP_LANES)]} {
    set ::env(TINYSPAN_BLOCK0_PARTITION_TAP_LANES) "16"
}

set top_module $::env(TINYSPAN_BLOCK0_PARTITION_TOP)
set tag $::env(TINYSPAN_BLOCK0_PARTITION_TAG)
set proj_dir [file join $origin_dir build "vivado_tinyspan_w8a8_${tag}_synth"]

file delete -force $proj_dir
file mkdir $proj_dir
create_project "tinyspan_w8a8_${tag}_synth" $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_param general.maxThreads 1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_sources [list \
    [file join $origin_dir rtl span span_rgb_line_window3x3.v] \
    [file join $origin_dir rtl span span_w8a12_weight_group_rom.v] \
    [file join $origin_dir rtl span span_w8a12_parallel_mac_tile.v] \
    [file join $origin_dir rtl span span_w8a12_parallel_group_accum_engine.v] \
    [file join $origin_dir rtl span span_w8a12_requant_pipe.v] \
    [file join $origin_dir rtl span span_w8a12_parallel_conv_vector_streamed_weights.v] \
    [file join $origin_dir rtl span span_w8a12_feature_line_window3x3.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_feature_conv_streamed_frontend.v] \
    [file join $origin_dir rtl span span_w8a12_unary_lut.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_rgb_window_quantize.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_head_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_scale_add_q31.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_scale_mul_q31.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_scale_q31_symmetric.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_reconstruct_concat_requant.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_base_add_equiv.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_bicubic_base_x4_streamed.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_bicubic_base_x4_streamed_serial.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_qrgb_to_rgb888.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_full_streamed_rgb888_base_equiv.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block_postprocess_serial.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block0_c1_vector_top.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block0_c2_vector_top.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block0_c3_vector_top.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block0_postprocess_top.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block0_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block1_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block2_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_block3_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_blocks0123_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_blocks0123_taps_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_fuse_tail_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_reconstruct_streamed_frontend.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_tail_streamed_rgb_no_base.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_trunk_tail_streamed_rgb_no_base.v] \
    [file join $origin_dir rtl span span_tinyspan_w8a8_full_streamed_rgb_no_base.v] \
    [file join $origin_dir rtl span span_w8a12_pixelshuffle_x4_streamed_rgb.v] \
    [file join $origin_dir rtl generated tinyspan_c32b4_30fps_frozen_w8a8 tinyspan_w8a8_layers.vh] \
]
add_files -fileset sources_1 $rtl_sources
set_property include_dirs [list \
    [file join $origin_dir rtl] \
    [file join $origin_dir rtl generated] \
    [file join $origin_dir rtl generated tinyspan_c32b4_30fps_frozen_w8a8] \
] [get_filesets sources_1]
set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

set synth_generics [list \
    IMG_W=$::env(TINYSPAN_BLOCK0_PARTITION_IMG_W) \
    IMG_H=$::env(TINYSPAN_BLOCK0_PARTITION_IMG_H) \
    OUT_LANES=$::env(TINYSPAN_BLOCK0_PARTITION_OUT_LANES) \
    TAP_LANES=$::env(TINYSPAN_BLOCK0_PARTITION_TAP_LANES) \
]
if {[info exists ::env(TINYSPAN_BLOCK0_PARTITION_USE_SERIAL_BASE)]} {
    lappend synth_generics USE_SERIAL_BASE=$::env(TINYSPAN_BLOCK0_PARTITION_USE_SERIAL_BASE)
}

synth_design \
    -top $top_module \
    -part xczu19eg-ffvc1760-2-i \
    -mode out_of_context \
    -flatten_hierarchy none \
    -generic $synth_generics

if {[llength [get_ports clk]] > 0} {
    create_clock -period $::env(TINYSPAN_BLOCK0_PARTITION_CLOCK_PERIOD_NS) -name clk [get_ports clk]
}

report_utilization -file [file join $proj_dir "${tag}_utilization.rpt"]
report_utilization -hierarchical -hierarchical_depth 6 -file [file join $proj_dir "${tag}_hierarchical_utilization.rpt"]
report_timing_summary -file [file join $proj_dir "${tag}_timing.rpt"]
write_checkpoint -force [file join $proj_dir "${tag}_synth.dcp"]
puts "PASS tinyspan_w8a8_block0_partition top=$top_module tag=$tag"
quit
