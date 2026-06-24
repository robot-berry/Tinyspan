proc tinyspan_disable_tclapp_autoload {} {
    if {[llength [info commands ::tclapp::load_apps]] > 0} {
        catch {rename ::tclapp::load_apps ::tclapp::_tinyspan_orig_load_apps}
    }
    proc ::tclapp::tinyspan_stub_register_options {args} {
        set ns ""
        for {set i 0} {$i < [llength $args]} {incr i} {
            if {[lindex $args $i] eq "-namespace" && [expr {$i + 1}] < [llength $args]} {
                set ns [lindex $args [expr {$i + 1}]]
            }
        }
        if {$ns eq "" && [llength $args] > 0} {
            set ns [lindex $args end]
        }
        if {$ns ne ""} {
            set full_ns "::tclapp::${ns}"
            namespace eval $full_ns {}
            proc ${full_ns}::register_options {args} {return 0}
        }
    }
    proc ::tclapp::load_apps {args} {
        ::tclapp::tinyspan_stub_register_options {*}$args
        return ""
    }
    proc ::tclapp::load_app {args} {
        ::tclapp::tinyspan_stub_register_options {*}$args
        return ""
    }
}

if {$argc < 1} {
    error "Usage: program_tinyspan_ps_ddr_bitstream.tcl <bitstream>"
}

set bitstream_path [file normalize [lindex $argv 0]]
if {![file exists $bitstream_path]} {
    error "Bitstream not found: $bitstream_path"
}

tinyspan_disable_tclapp_autoload
catch {set_param labtools.enable_cs_server 0}
catch {puts "TINYSPAN_PS_DDR_X4_PROGRAM_LABTOOLS_ENABLE_CS_SERVER=[get_param labtools.enable_cs_server]"}

open_hw_manager
connect_hw_server
set targets [get_hw_targets -quiet *]
puts "TINYSPAN_PS_DDR_X4_PROGRAM_TARGET_COUNT=[llength $targets]"
foreach target_name $targets {
    puts "TINYSPAN_PS_DDR_X4_PROGRAM_TARGET_CANDIDATE=$target_name"
}
if {[llength $targets] == 0} {
    error "No Vivado hardware target found for programming."
}

open_hw_target [lindex $targets 0]
set devices [get_hw_devices -quiet]
puts "TINYSPAN_PS_DDR_X4_PROGRAM_DEVICE_COUNT=[llength $devices]"
foreach dev_name $devices {
    puts "TINYSPAN_PS_DDR_X4_PROGRAM_DEVICE=$dev_name"
}
if {[llength $devices] == 0} {
    error "No Vivado hardware device found for programming."
}

set dev [lindex $devices 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROGRAM.FILE $bitstream_path $dev
puts "TINYSPAN_PS_DDR_X4_PROGRAM_BITSTREAM=$bitstream_path"
program_hw_devices $dev
refresh_hw_device -update_hw_probes false $dev
puts "TINYSPAN_PS_DDR_X4_PROGRAM_PASS=1"
