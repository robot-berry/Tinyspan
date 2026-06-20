set script_dir [file dirname [file normalize [info script]]]
set root_dir [file normalize [file join $script_dir .. .. ..]]
set proj [file join $root_dir vivado jfs jfs.xpr]
set rpt_dir [file join $root_dir vivado reports]

if {![file exists $proj]} {
    puts "ERROR: Vivado project does not exist: $proj"
    exit 1
}

file mkdir $rpt_dir
if {[info exists ::env(JFS_POWER_REPORT_NAME)] && $::env(JFS_POWER_REPORT_NAME) ne ""} {
    set report_name $::env(JFS_POWER_REPORT_NAME)
} else {
    set report_name "jtag_full_span_power_impl.rpt"
}
set report_path [file join $rpt_dir $report_name]

open_project $proj
open_run impl_1
report_power -file $report_path

puts "JFS_POWER_PROJECT=$proj"
puts "JFS_POWER_REPORT=$report_path"

close_project
quit
