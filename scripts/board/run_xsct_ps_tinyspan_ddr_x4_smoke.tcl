if {[llength $argv] < 13} {
    error "Usage: run_xsct_ps_tinyspan_ddr_x4_smoke.tcl <psu_init.tcl> <ctrl_base> <input.raw> <output.hex> <img_w> <img_h> <scale> <input_base> <output_base> <timeout_ms> <readback_mode> <readback_pixels> <clear_output>"
}

set psu_init_tcl [file normalize [lindex $argv 0]]
set ctrl_base [lindex $argv 1]
set input_raw [file normalize [lindex $argv 2]]
set output_hex [file normalize [lindex $argv 3]]
set img_w [expr {int([lindex $argv 4])}]
set img_h [expr {int([lindex $argv 5])}]
set scale [expr {int([lindex $argv 6])}]
set input_base [lindex $argv 7]
set output_base [lindex $argv 8]
set timeout_ms [expr {int([lindex $argv 9])}]
set readback_mode [string toupper [lindex $argv 10]]
set readback_pixels [expr {int([lindex $argv 11])}]
set clear_output [expr {int([lindex $argv 12])}]

if {$readback_mode ne "FULL" && $readback_mode ne "SAMPLE" && $readback_mode ne "SKIP"} {
    error "Unsupported readback_mode: $readback_mode"
}
if {![file exists $psu_init_tcl]} {
    error "psu_init.tcl not found: $psu_init_tcl"
}
if {![file exists $input_raw]} {
    error "input raw not found: $input_raw"
}

set reg_control         [expr {$ctrl_base + 0x00}]
set reg_status          [expr {$ctrl_base + 0x04}]
set reg_img_w           [expr {$ctrl_base + 0x08}]
set reg_img_h           [expr {$ctrl_base + 0x0c}]
set reg_input_base      [expr {$ctrl_base + 0x10}]
set reg_output_base     [expr {$ctrl_base + 0x14}]
set reg_frame_cycles_lo [expr {$ctrl_base + 0x18}]
set reg_frame_cycles_hi [expr {$ctrl_base + 0x1c}]
set reg_tiles_done      [expr {$ctrl_base + 0x20}]
set reg_error           [expr {$ctrl_base + 0x24}]
set reg_config          [expr {$ctrl_base + 0x28}]

set in_pixels [expr {$img_w * $img_h}]
set out_w [expr {$img_w * $scale}]
set out_h [expr {$img_h * $scale}]
set out_pixels [expr {$out_w * $out_h}]
set expected_bytes [expr {$in_pixels * 3}]
set actual_bytes [file size $input_raw]
if {$actual_bytes != $expected_bytes} {
    error "input raw size mismatch: got $actual_bytes expected $expected_bytes"
}

proc try_target {filter label} {
    if {[catch {targets -set -filter $filter} err]} {
        puts "TINYSPAN_PS_DDR_X4_TARGET_SELECT_FAIL_${label}=$err"
        return 0
    }
    puts "TINYSPAN_PS_DDR_X4_TARGET_SELECT_PASS_${label}=1"
    return 1
}

proc select_access_target {label} {
    if {[try_target {name =~ "DAP"} "${label}_DAP"]} {
        return 1
    }
    if {[try_target {name =~ "Cortex-A53 #0"} "${label}_A53_0"]} {
        return 1
    }
    if {[try_target {name =~ "*Cortex-A53*#0*"} "${label}_A53_0_GLOB"]} {
        return 1
    }
    if {[try_target {name =~ "PSU"} "${label}_PSU"]} {
        return 1
    }
    return 0
}

proc read32 {addr} {
    set last_err ""
    for {set attempt 1} {$attempt <= 5} {incr attempt} {
        if {![catch {mrd -value $addr 1} value]} {
            return [expr {$value & 0xffffffff}]
        }
        set last_err $value
        puts [format "TINYSPAN_PS_DDR_X4_MRD_RETRY addr=0x%08X attempt=%d err=%s" $addr $attempt $value]
        if {[string first "Invalid context" $value] >= 0 || [string first "no targets found" $value] >= 0} {
            select_access_target "MRD_RETRY"
        }
        after [expr {$attempt * 200}]
    }
    error [format "mrd failed after retries addr=0x%08X err=%s" $addr $last_err]
}

proc write32 {addr value} {
    set word [expr {$value & 0xffffffff}]
    set last_err ""
    for {set attempt 1} {$attempt <= 5} {incr attempt} {
        if {![catch {mwr $addr $word} err]} {
            return
        }
        set last_err $err
        puts [format "TINYSPAN_PS_DDR_X4_MWR_RETRY addr=0x%08X attempt=%d err=%s" $addr $attempt $err]
        if {[string first "Invalid context" $err] >= 0 || [string first "no targets found" $err] >= 0} {
            select_access_target "MWR_RETRY"
        }
        after [expr {$attempt * 200}]
    }
    error [format "mwr failed after retries addr=0x%08X err=%s" $addr $last_err]
}

proc align_up {value align} {
    return [expr {(($value + $align - 1) / $align) * $align}]
}

proc add_mem_region {addr size label} {
    if {[catch {memmap -addr $addr -size $size -flags 3} err]} {
        error [format "Failed to add XSCT memory map %s at 0x%08X size 0x%X: %s" $label $addr $size $err]
    }
    puts [format "TINYSPAN_PS_DDR_X4_MEMMAP_%s=0x%08X+0x%X" $label $addr $size]
}

proc write_input_rgb_to_ddr {input_raw input_base in_pixels} {
    set f [open $input_raw rb]
    fconfigure $f -translation binary
    set data [read $f]
    close $f
    binary scan $data c* bytes
    for {set i 0} {$i < $in_pixels} {incr i} {
        set r [expr {[lindex $bytes [expr {$i * 3 + 0}]] & 0xff}]
        set g [expr {[lindex $bytes [expr {$i * 3 + 1}]] & 0xff}]
        set b [expr {[lindex $bytes [expr {$i * 3 + 2}]] & 0xff}]
        set pix [expr {($r << 16) | ($g << 8) | $b}]
        write32 [expr {$input_base + $i * 4}] $pix
    }
    return $in_pixels
}

proc clear_output_ddr {output_base out_pixels} {
    for {set i 0} {$i < $out_pixels} {incr i} {
        write32 [expr {$output_base + $i * 4}] 0
    }
    return $out_pixels
}

proc read_ddr_frame_hex {output_hex output_base read_pixels} {
    set out_dir [file dirname $output_hex]
    file mkdir $out_dir
    set fo [open $output_hex w]
    for {set i 0} {$i < $read_pixels} {incr i} {
        set pix [read32 [expr {$output_base + $i * 4}]]
        puts $fo [format "%06X" [expr {$pix & 0x00ffffff}]]
    }
    close $fo
    return $read_pixels
}

connect
after 1000
puts "TINYSPAN_PS_DDR_X4_XSCT_TARGETS_BEGIN"
targets
puts "TINYSPAN_PS_DDR_X4_XSCT_TARGETS_END"

if {[try_target {name =~ "PS TAP"} "PS_TAP"]} {
    if {[catch {rst -system} err]} {
        puts "TINYSPAN_PS_DDR_X4_SYSTEM_RESET_FAIL=$err"
    } else {
        puts "TINYSPAN_PS_DDR_X4_SYSTEM_RESET_PASS=1"
    }
    after 3000
}

if {[try_target {name =~ "PSU"} "PSU"]} {
    source $psu_init_tcl
    puts "TINYSPAN_PS_DDR_X4_PSU_INIT_SOURCE=$psu_init_tcl"
    psu_init
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
    puts "TINYSPAN_PS_DDR_X4_PSU_INIT_PASS=1"
} else {
    puts "TINYSPAN_PS_DDR_X4_PSU_INIT_TARGET_MISSING=1"
    if {[try_target {name =~ "PMU"} "PMU_INIT_FALLBACK"]} {
        catch {rst -system}
        after 1000
        source $psu_init_tcl
        puts "TINYSPAN_PS_DDR_X4_PMU_INIT_SOURCE=$psu_init_tcl"
        if {[catch {psu_init} err]} {
            puts "TINYSPAN_PS_DDR_X4_PMU_PSU_INIT_FAIL=$err"
        } else {
            catch {psu_ps_pl_isolation_removal}
            catch {psu_ps_pl_reset_config}
            puts "TINYSPAN_PS_DDR_X4_PMU_PSU_INIT_PASS=1"
        }
    } else {
        puts "TINYSPAN_PS_DDR_X4_PSU_INIT_SKIPPED=1"
    }
}

if {![select_access_target "ACCESS"]} {
    error "Could not select DAP, PSU, or A53 target for AXI/DDR accesses"
}

set ctrl_map_size 0x10000
set input_map_size [align_up [expr {$in_pixels * 4}] 0x1000]
set output_map_size [align_up [expr {$out_pixels * 4}] 0x1000]
if {$input_map_size < 0x10000} {
    set input_map_size 0x10000
}
if {$output_map_size < 0x10000} {
    set output_map_size 0x10000
}
add_mem_region $ctrl_base $ctrl_map_size "CTRL_AXI_LITE"
add_mem_region $input_base $input_map_size "INPUT_DDR"
add_mem_region $output_base $output_map_size "OUTPUT_DDR"

puts [format "TINYSPAN_PS_DDR_X4_CTRL_BASE=0x%08X" $ctrl_base]
puts [format "TINYSPAN_PS_DDR_X4_INPUT_BASE=0x%08X" $input_base]
puts [format "TINYSPAN_PS_DDR_X4_OUTPUT_BASE=0x%08X" $output_base]
puts "TINYSPAN_PS_DDR_X4_IMG_W=$img_w"
puts "TINYSPAN_PS_DDR_X4_IMG_H=$img_h"
puts "TINYSPAN_PS_DDR_X4_SCALE=$scale"
puts "TINYSPAN_PS_DDR_X4_INPUT_PIXELS=$in_pixels"
puts "TINYSPAN_PS_DDR_X4_OUTPUT_PIXELS=$out_pixels"
puts "TINYSPAN_PS_DDR_X4_READBACK_MODE=$readback_mode"
puts "TINYSPAN_PS_DDR_X4_READBACK_PIXELS_REQUEST=$readback_pixels"
puts "TINYSPAN_PS_DDR_X4_CLEAR_OUTPUT=$clear_output"

write32 $reg_control 0x2
after 10
write32 $reg_img_w $img_w
write32 $reg_img_h $img_h
write32 $reg_input_base $input_base
write32 $reg_output_base $output_base
set img_w_readback [read32 $reg_img_w]
set img_h_readback [read32 $reg_img_h]
set input_base_readback [read32 $reg_input_base]
set output_base_readback [read32 $reg_output_base]
puts [format "TINYSPAN_PS_DDR_X4_IMG_W_READBACK=%d" $img_w_readback]
puts [format "TINYSPAN_PS_DDR_X4_IMG_H_READBACK=%d" $img_h_readback]
puts [format "TINYSPAN_PS_DDR_X4_INPUT_BASE_READBACK=0x%08X" $input_base_readback]
puts [format "TINYSPAN_PS_DDR_X4_OUTPUT_BASE_READBACK=0x%08X" $output_base_readback]
if {$img_w_readback != $img_w || $img_h_readback != $img_h ||
    $input_base_readback != ($input_base & 0xffffffff) ||
    $output_base_readback != ($output_base & 0xffffffff)} {
    error "TinySPAN PS DDR register readback mismatch"
}
puts [format "TINYSPAN_PS_DDR_X4_CONFIG=0x%08X" [read32 $reg_config]]
puts [format "TINYSPAN_PS_DDR_X4_STATUS_AFTER_CLEAR=0x%08X" [read32 $reg_status]]

set input_words [write_input_rgb_to_ddr $input_raw $input_base $in_pixels]
puts "TINYSPAN_PS_DDR_X4_INPUT_DDR_WRITE_WORDS=$input_words"
if {$clear_output != 0} {
    set clear_words [clear_output_ddr $output_base $out_pixels]
    puts "TINYSPAN_PS_DDR_X4_OUTPUT_DDR_CLEAR_WORDS=$clear_words"
} else {
    puts "TINYSPAN_PS_DDR_X4_OUTPUT_DDR_CLEAR_SKIPPED=1"
}
flush stdout

puts "TINYSPAN_PS_DDR_X4_START_WRITE_BEGIN=1"
flush stdout
write32 $reg_control 0x1
puts "TINYSPAN_PS_DDR_X4_START_WRITE_DONE=1"
flush stdout
after 200
puts "TINYSPAN_PS_DDR_X4_POST_START_DELAY_MS=200"
flush stdout

set poll_start [clock milliseconds]
set status 0
set done 0
set err 0
while {([clock milliseconds] - $poll_start) < $timeout_ms} {
    set status [read32 $reg_status]
    set err [read32 $reg_error]
    if {($status & 0x08) != 0} {
        set done 1
        break
    }
    if {($status & 0x10) != 0 || $err != 0} {
        break
    }
    after 20
}

set status [read32 $reg_status]
set err [read32 $reg_error]
set cycles_lo [read32 $reg_frame_cycles_lo]
set cycles_hi [read32 $reg_frame_cycles_hi]
set tiles_done [read32 $reg_tiles_done]
set config [read32 $reg_config]
set frame_cycles [expr {($cycles_hi * 4294967296) + $cycles_lo}]

set output_read_pixels 0
if {$done != 0 && $err == 0 && ($status & 0x10) == 0} {
    if {$readback_mode eq "FULL"} {
        set output_read_pixels [read_ddr_frame_hex $output_hex $output_base $out_pixels]
    } elseif {$readback_mode eq "SAMPLE"} {
        if {$readback_pixels <= 0 || $readback_pixels > $out_pixels} {
            set readback_pixels $out_pixels
        }
        set output_read_pixels [read_ddr_frame_hex $output_hex $output_base $readback_pixels]
    } else {
        puts "TINYSPAN_PS_DDR_X4_OUTPUT_READBACK_SKIPPED=1"
    }
}

puts [format "TINYSPAN_PS_DDR_X4_STATUS=0x%08X" $status]
puts [format "TINYSPAN_PS_DDR_X4_ERROR=0x%08X" $err]
puts "TINYSPAN_PS_DDR_X4_FRAME_DONE=$done"
puts [format "TINYSPAN_PS_DDR_X4_FRAME_CYCLES_LO=0x%08X" $cycles_lo]
puts [format "TINYSPAN_PS_DDR_X4_FRAME_CYCLES_HI=0x%08X" $cycles_hi]
puts "TINYSPAN_PS_DDR_X4_FRAME_CYCLES=$frame_cycles"
puts "TINYSPAN_PS_DDR_X4_TILES_DONE=$tiles_done"
puts [format "TINYSPAN_PS_DDR_X4_CONFIG_FINAL=0x%08X" $config]
puts "TINYSPAN_PS_DDR_X4_OUTPUT_HEX=$output_hex"
puts "TINYSPAN_PS_DDR_X4_OUTPUT_READ_PIXELS=$output_read_pixels"

if {$done == 0} {
    error "TinySPAN PS DDR X4 did not finish before timeout"
}
if {$err != 0 || ($status & 0x10) != 0} {
    error [format "TinySPAN PS DDR X4 reported status 0x%08X error 0x%08X" $status $err]
}
if {$readback_mode eq "FULL" && $output_read_pixels != $out_pixels} {
    error [format "TinySPAN PS DDR X4 full readback mismatch: got %d expected %d" $output_read_pixels $out_pixels]
}
if {$readback_mode eq "SAMPLE" && $output_read_pixels <= 0} {
    error "TinySPAN PS DDR X4 sample readback produced no pixels"
}

puts "TINYSPAN_PS_DDR_X4_XSCT_PASS=1"
