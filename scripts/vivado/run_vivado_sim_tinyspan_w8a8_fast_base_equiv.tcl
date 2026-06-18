set script_dir [file normalize [file dirname [info script]]]
if {[file tail $script_dir] eq "vivado"} {
    set origin_dir [file normalize [file join $script_dir .. ..]]
} else {
    set origin_dir [file normalize [file join $script_dir ..]]
}

if {![info exists ::env(TINYSPAN_FAST_BASE_PROJ)]} {
    set ::env(TINYSPAN_FAST_BASE_PROJ) "vivado_tinyspan_w8a8_fast_base_equiv_sim"
}
if {![info exists ::env(TINYSPAN_FAST_BASE_TOP)]} {
    set ::env(TINYSPAN_FAST_BASE_TOP) "tb_span_tinyspan_w8a8_bicubic_base_x4_fast_vs_serial"
}

set top_name $::env(TINYSPAN_FAST_BASE_TOP)
set proj_dir [file join $origin_dir build $::env(TINYSPAN_FAST_BASE_PROJ)]
set span_dir [file join $origin_dir rtl span]
set tb_file [file join $origin_dir sim tb_span_tinyspan_w8a8_bicubic_base_x4_fast_vs_serial.sv]
if {![file exists $tb_file]} {
    set tb_file [file join $origin_dir sim testbench tb_span_tinyspan_w8a8_bicubic_base_x4_fast_vs_serial.sv]
}
if {![file exists [file join $span_dir span_tinyspan_w8a8_bicubic_base_x4_streamed.v]]} {
    set span_dir [file join $origin_dir rtl tinyspan_core]
}

file delete -force $proj_dir
file mkdir $proj_dir
create_project $::env(TINYSPAN_FAST_BASE_PROJ) $proj_dir -part xczu19eg-ffvc1760-2-i -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_sources [list \
    [file join $span_dir span_tinyspan_w8a8_bicubic_base_x4_streamed.v] \
    [file join $span_dir span_tinyspan_w8a8_bicubic_base_x4_streamed_serial.v] \
]

add_files -fileset sources_1 $rtl_sources
add_files -fileset sim_1 $rtl_sources
add_files -fileset sim_1 $tb_file
set_property top $top_name [get_filesets sim_1]
set_property xsim.simulate.runtime 200us [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

launch_simulation
close_sim
quit
