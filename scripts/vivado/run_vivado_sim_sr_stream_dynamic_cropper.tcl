set script_dir [file normalize [file dirname [info script]]]
if {[file tail $script_dir] eq "vivado"} {
    set origin_dir [file normalize [file join $script_dir .. ..]]
} else {
    set origin_dir [file normalize [file join $script_dir ..]]
}
set proj_dir   [file join $origin_dir build vivado_sr_stream_dynamic_cropper_sim]
set board_dir  [file join $origin_dir rtl board]
if {![file exists [file join $board_dir sr_stream_dynamic_cropper.v]]} {
    set board_dir [file join $origin_dir rtl board_wrapper]
}
set tb_file [file join $origin_dir sim tb_sr_stream_dynamic_cropper.sv]
if {![file exists $tb_file]} {
    set tb_file [file join $origin_dir sim testbench tb_sr_stream_dynamic_cropper.sv]
}

file delete -force $proj_dir
file mkdir $proj_dir
create_project sr_stream_dynamic_cropper_sim $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_sources [list \
    [file join $board_dir sr_stream_dynamic_cropper.v] \
]

add_files -fileset sources_1 $rtl_sources
add_files -fileset sim_1 $rtl_sources
add_files -fileset sim_1 $tb_file
set_property top tb_sr_stream_dynamic_cropper [get_filesets sim_1]
set_property xsim.simulate.runtime 2ms [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
close_sim
quit
