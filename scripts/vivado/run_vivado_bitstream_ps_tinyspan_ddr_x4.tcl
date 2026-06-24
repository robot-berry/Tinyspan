set script_dir [file normalize [file dirname [info script]]]
if {[file tail $script_dir] eq "vivado"} {
    set origin_dir [file normalize [file join $script_dir .. ..]]
} else {
    set origin_dir [file normalize [file join $script_dir ..]]
}

source [file join $script_dir create_vivado_ps_tinyspan_ddr_x4_bd_project.tcl]

set proj_dir [file join $origin_dir vivado ps_tinyspan_ddr_x4]
if {[info exists ::env(PS_TINYSPAN_DDR_X4_PROJECT_DIR)]} {
    set proj_dir [file normalize $::env(PS_TINYSPAN_DDR_X4_PROJECT_DIR)]
}
set bd_name pstinyspanx4ddr
set rpt_dir [file join $proj_dir reports]
set bit_dir [file join $proj_dir ps_tinyspan_ddr_x4.runs impl_1]
file mkdir $rpt_dir
file mkdir $bit_dir

set max_threads 1
if {[info exists ::env(PS_TINYSPAN_DDR_X4_MAX_THREADS)]} {
    set max_threads $::env(PS_TINYSPAN_DDR_X4_MAX_THREADS)
}
set synth_directive RuntimeOptimized
if {[info exists ::env(PS_TINYSPAN_DDR_X4_SYNTH_DIRECTIVE)]} {
    set synth_directive $::env(PS_TINYSPAN_DDR_X4_SYNTH_DIRECTIVE)
}
set place_directive Default
if {[info exists ::env(PS_TINYSPAN_DDR_X4_PLACE_DIRECTIVE)]} {
    set place_directive $::env(PS_TINYSPAN_DDR_X4_PLACE_DIRECTIVE)
}
set phys_opt_directive Default
if {[info exists ::env(PS_TINYSPAN_DDR_X4_PHYS_OPT_DIRECTIVE)]} {
    set phys_opt_directive $::env(PS_TINYSPAN_DDR_X4_PHYS_OPT_DIRECTIVE)
}
set route_directive Default
if {[info exists ::env(PS_TINYSPAN_DDR_X4_ROUTE_DIRECTIVE)]} {
    set route_directive $::env(PS_TINYSPAN_DDR_X4_ROUTE_DIRECTIVE)
}
set post_route_phys_opt_directive Default
if {[info exists ::env(PS_TINYSPAN_DDR_X4_POST_ROUTE_PHYS_OPT_DIRECTIVE)]} {
    set post_route_phys_opt_directive $::env(PS_TINYSPAN_DDR_X4_POST_ROUTE_PHYS_OPT_DIRECTIVE)
}

set_param general.maxThreads $max_threads
puts "PS_TINYSPAN_DDR_X4_MAX_THREADS=$max_threads"
puts "PS_TINYSPAN_DDR_X4_SYNTH_DIRECTIVE=$synth_directive"
puts "PS_TINYSPAN_DDR_X4_PLACE_DIRECTIVE=$place_directive"
puts "PS_TINYSPAN_DDR_X4_PHYS_OPT_DIRECTIVE=$phys_opt_directive"
puts "PS_TINYSPAN_DDR_X4_ROUTE_DIRECTIVE=$route_directive"
puts "PS_TINYSPAN_DDR_X4_POST_ROUTE_PHYS_OPT_DIRECTIVE=$post_route_phys_opt_directive"
puts "PS_TINYSPAN_DDR_X4_DDR_POLICY=use ZynqMP PS DDR controller IP; no custom DDR controller or PHY"

set bd_file [get_files [file join $proj_dir ps_tinyspan_ddr_x4.srcs sources_1 bd $bd_name ${bd_name}.bd]]
puts "PS_TINYSPAN_DDR_X4_STAGE=generate_target"
generate_target all $bd_file
update_compile_order -fileset sources_1

set synth_args [list \
    -top ${bd_name}_wrapper \
    -part $part_name \
    -flatten_hierarchy none \
]
if {$synth_directive ne "Default"} {
    lappend synth_args -directive $synth_directive
}

puts "PS_TINYSPAN_DDR_X4_STAGE=synth_design"
synth_design {*}$synth_args
write_checkpoint -force [file join $bit_dir ${bd_name}_wrapper_synth.dcp]
report_utilization -file [file join $rpt_dir ps_tinyspan_ddr_x4_utilization_synth.rpt]
report_timing_summary -file [file join $rpt_dir ps_tinyspan_ddr_x4_timing_synth.rpt]

puts "PS_TINYSPAN_DDR_X4_STAGE=opt_design"
opt_design
write_checkpoint -force [file join $bit_dir ${bd_name}_wrapper_opt.dcp]

puts "PS_TINYSPAN_DDR_X4_STAGE=place_design"
set place_args [list]
if {$place_directive ne "Default" && $place_directive ne ""} {
    lappend place_args -directive $place_directive
}
place_design {*}$place_args
if {$phys_opt_directive ne "None"} {
    set phys_opt_args [list]
    if {$phys_opt_directive ne "Default" && $phys_opt_directive ne ""} {
        lappend phys_opt_args -directive $phys_opt_directive
    }
    phys_opt_design {*}$phys_opt_args
}
write_checkpoint -force [file join $bit_dir ${bd_name}_wrapper_placed.dcp]
report_utilization -file [file join $rpt_dir ps_tinyspan_ddr_x4_utilization_place.rpt]
report_timing_summary -file [file join $rpt_dir ps_tinyspan_ddr_x4_timing_place.rpt]
catch {report_design_analysis -congestion -file [file join $rpt_dir ps_tinyspan_ddr_x4_congestion_place.rpt]}

puts "PS_TINYSPAN_DDR_X4_STAGE=route_design"
set route_args [list]
if {$route_directive ne "Default" && $route_directive ne ""} {
    lappend route_args -directive $route_directive
}
if {[catch {route_design {*}$route_args} route_err route_opts]} {
    catch {report_route_status -file [file join $rpt_dir ps_tinyspan_ddr_x4_route_status_failed.rpt]}
    catch {report_design_analysis -congestion -file [file join $rpt_dir ps_tinyspan_ddr_x4_congestion_route_failed.rpt]}
    puts "PS_TINYSPAN_DDR_X4_ROUTE_ERROR=$route_err"
    return -options $route_opts $route_err
}
if {$post_route_phys_opt_directive ne "None"} {
    set post_route_phys_opt_args [list]
    if {$post_route_phys_opt_directive ne "Default" && $post_route_phys_opt_directive ne ""} {
        lappend post_route_phys_opt_args -directive $post_route_phys_opt_directive
    }
    phys_opt_design {*}$post_route_phys_opt_args
}
write_checkpoint -force [file join $bit_dir ${bd_name}_wrapper_routed.dcp]

report_utilization -file [file join $rpt_dir ps_tinyspan_ddr_x4_utilization_impl.rpt]
report_timing_summary -file [file join $rpt_dir ps_tinyspan_ddr_x4_timing_impl.rpt]
report_route_status -file [file join $rpt_dir ps_tinyspan_ddr_x4_route_status_impl.rpt]
catch {report_power -file [file join $rpt_dir ps_tinyspan_ddr_x4_power_impl.rpt]}
catch {report_design_analysis -congestion -file [file join $rpt_dir ps_tinyspan_ddr_x4_congestion_impl.rpt]}

puts "PS_TINYSPAN_DDR_X4_STAGE=write_bitstream"
write_bitstream -force [file join $bit_dir ${bd_name}_wrapper.bit]

puts "PASS run_vivado_bitstream_ps_tinyspan_ddr_x4"
puts "PS_TINYSPAN_DDR_X4_PROJECT=[file join $proj_dir ps_tinyspan_ddr_x4.xpr]"
puts "PS_TINYSPAN_DDR_X4_BIT=[file join $bit_dir ${bd_name}_wrapper.bit]"
puts "PS_TINYSPAN_DDR_X4_UTIL=[file join $rpt_dir ps_tinyspan_ddr_x4_utilization_impl.rpt]"
puts "PS_TINYSPAN_DDR_X4_TIMING=[file join $rpt_dir ps_tinyspan_ddr_x4_timing_impl.rpt]"
puts "PS_TINYSPAN_DDR_X4_POWER=[file join $rpt_dir ps_tinyspan_ddr_x4_power_impl.rpt]"

quit
