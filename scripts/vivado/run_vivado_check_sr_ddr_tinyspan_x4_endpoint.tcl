set script_dir [file normalize [file dirname [info script]]]
if {[file tail $script_dir] eq "vivado"} {
    set origin_dir [file normalize [file join $script_dir .. ..]]
} else {
    set origin_dir [file normalize [file join $script_dir ..]]
}

set proj_name ddr_ttx4_elab
set proj_dir  [file join $origin_dir build ddr_ttx4_elab]
set span_dir  [file join $origin_dir rtl tinyspan_core]
set board_dir [file join $origin_dir rtl board_wrapper]

file delete -force $proj_dir
file mkdir $proj_dir
create_project $proj_name $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property xpm_libraries {XPM_MEMORY} [current_project]

proc add_required_file {path} {
    if {![file exists $path]} {
        error "Required RTL file not found: $path"
    }
    add_files -fileset sources_1 $path
}

set rtl_sources [list \
    [file join $board_dir sr_tile_scheduler.v] \
    [file join $board_dir sr_tile_rgb_buffer_streamer.v] \
    [file join $board_dir sr_tile_fetch_stream_shell.v] \
    [file join $board_dir sr_tile_output_writer.v] \
    [file join $board_dir sr_stream_dynamic_cropper.v] \
    [file join $board_dir sr_tile_tinyspan_x4_writer_shell.v] \
    [file join $board_dir sr_ddr_pixel_axi_master.v] \
    [file join $board_dir sr_ddr_tinyspan_x4_tile_writer_endpoint.v] \
    [file join $span_dir span_tinyspan_w8a8_bicubic_base_x2_streamed.v] \
    [file join $span_dir span_tinyspan_w8a8_bicubic_base_x4_streamed.v] \
    [file join $span_dir span_tinyspan_w8a8_bicubic_base_x4_streamed_serial.v] \
    [file join $span_dir span_tinyspan_w8a8_scale_q31_symmetric.v] \
    [file join $span_dir span_tinyspan_w8a8_base_add_equiv.v] \
    [file join $span_dir span_tinyspan_w8a8_qrgb_to_rgb888.v] \
    [file join $span_dir span_tinyspan_w8a8_full_streamed_rgb_base_equiv.v] \
    [file join $span_dir span_tinyspan_w8a8_full_streamed_rgb888_base_equiv.v] \
]

foreach src $rtl_sources {
    add_required_file $src
}

set_property top sr_ddr_tinyspan_x4_tile_writer_endpoint [current_fileset]
update_compile_order -fileset sources_1

set synth_args [list \
    -rtl \
    -top sr_ddr_tinyspan_x4_tile_writer_endpoint \
    -part xczu19eg-ffvc1760-2-i \
]
foreach {env_name generic_name} {
    PS_TINYSPAN_DDR_X4_SCALE SCALE
    PS_TINYSPAN_DDR_X4_IMG_W DEFAULT_IMG_W
    PS_TINYSPAN_DDR_X4_IMG_H DEFAULT_IMG_H
    PS_TINYSPAN_DDR_X4_TILE_W TILE_W
    PS_TINYSPAN_DDR_X4_TILE_H TILE_H
    PS_TINYSPAN_DDR_X4_USE_SERIAL_BASE USE_SERIAL_BASE
    PS_TINYSPAN_DDR_X4_BASE_Q31 BASE_Q31
    PS_TINYSPAN_DDR_X4_Q16_MULT Q16_MULT
} {
    if {[info exists ::env($env_name)]} {
        lappend synth_args -generic "${generic_name}=$::env($env_name)"
        puts "TINYSPAN_DDR_ENDPOINT_GENERIC_${generic_name}=$::env($env_name)"
    }
}

puts "TINYSPAN_DDR_ENDPOINT_STAGE=rtl_elaboration"
synth_design {*}$synth_args
puts "PASS sr_ddr_tinyspan_x4_tile_writer_endpoint rtl_elaboration"
quit
