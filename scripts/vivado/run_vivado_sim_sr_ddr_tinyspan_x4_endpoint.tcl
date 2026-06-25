set script_dir [file normalize [file dirname [info script]]]
if {[file tail $script_dir] eq "vivado"} {
    set origin_dir [file normalize [file join $script_dir .. ..]]
} else {
    set origin_dir [file normalize [file join $script_dir ..]]
}

set proj_name ddr_ttx4_endpoint_sim
if {[info exists ::env(TINYSPAN_DDR_ENDPOINT_SIM_PROJ)]} {
    set proj_name $::env(TINYSPAN_DDR_ENDPOINT_SIM_PROJ)
}
set proj_dir [file join $origin_dir build $proj_name]
set span_dir [file join $origin_dir rtl tinyspan_core]
set board_dir [file join $origin_dir rtl board_wrapper]
set top_name tb_sr_ddr_tinyspan_x4_endpoint_data
if {[info exists ::env(TINYSPAN_DDR_ENDPOINT_SIM_TOP)]} {
    set top_name $::env(TINYSPAN_DDR_ENDPOINT_SIM_TOP)
}
set sim_runtime 40ms
if {[info exists ::env(TINYSPAN_DDR_ENDPOINT_SIM_RUNTIME)]} {
    set sim_runtime $::env(TINYSPAN_DDR_ENDPOINT_SIM_RUNTIME)
}

set tb_file [file join $origin_dir sim testbench ${top_name}.sv]
if {![file exists $tb_file]} {
    set tb_file [file join $origin_dir sim ${top_name}.sv]
}
if {![file exists $tb_file]} {
    error "Endpoint simulation testbench not found: $tb_file"
}

file delete -force $proj_dir
file mkdir $proj_dir
create_project $proj_name $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property xpm_libraries {XPM_MEMORY} [current_project]

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
    if {![file exists $src]} {
        error "Required RTL file not found: $src"
    }
}

add_files -fileset sources_1 $rtl_sources
add_files -fileset sim_1 $rtl_sources
add_files -fileset sim_1 $tb_file
set_property top $top_name [get_filesets sim_1]
set_property xsim.simulate.runtime $sim_runtime [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
close_sim
quit
