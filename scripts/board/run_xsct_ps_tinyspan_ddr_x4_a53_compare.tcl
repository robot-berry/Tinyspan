if {[llength $argv] < 12} {
    error "Usage: run_xsct_ps_tinyspan_ddr_x4_a53_compare.tcl <psu_init.tcl> <compare.elf> <input_words.bin> <reference_rgb888.raw> <output_poison_words.bin> <ctrl_base> <img_w> <img_h> <scale> <input_base> <output_base> <reference_base> ?wait_ms? ?compare_timeout_ms?"
}

set psu_init_tcl [file normalize [lindex $argv 0]]
set elf_path [file normalize [lindex $argv 1]]
set input_words_bin [file normalize [lindex $argv 2]]
set reference_raw [file normalize [lindex $argv 3]]
set output_poison_words_bin [file normalize [lindex $argv 4]]
set ctrl_base [lindex $argv 5]
set img_w [expr {int([lindex $argv 6])}]
set img_h [expr {int([lindex $argv 7])}]
set scale [expr {int([lindex $argv 8])}]
set input_base [lindex $argv 9]
set output_base [lindex $argv 10]
set reference_base [lindex $argv 11]
set wait_ms 1000
if {[llength $argv] >= 13} {
    set wait_ms [expr {int([lindex $argv 12])}]
}
set compare_timeout_ms 30000
if {[llength $argv] >= 14} {
    set compare_timeout_ms [expr {int([lindex $argv 13])}]
}

set result_base 0xFFFD8000

if {![file exists $psu_init_tcl]} { error "psu_init.tcl not found: $psu_init_tcl" }
if {![file exists $elf_path]} { error "ELF not found: $elf_path" }
if {![file exists $input_words_bin]} { error "input words bin not found: $input_words_bin" }
if {![file exists $reference_raw]} { error "reference raw not found: $reference_raw" }
if {![file exists $output_poison_words_bin]} { error "output poison words bin not found: $output_poison_words_bin" }

set reg_control     [expr {$ctrl_base + 0x00}]
set reg_status      [expr {$ctrl_base + 0x04}]
set reg_img_w       [expr {$ctrl_base + 0x08}]
set reg_img_h       [expr {$ctrl_base + 0x0c}]
set reg_input_base  [expr {$ctrl_base + 0x10}]
set reg_output_base [expr {$ctrl_base + 0x14}]
set reg_frame_cycles_lo [expr {$ctrl_base + 0x18}]
set reg_frame_cycles_hi [expr {$ctrl_base + 0x1c}]
set reg_tiles_done  [expr {$ctrl_base + 0x20}]
set reg_error       [expr {$ctrl_base + 0x24}]
set reg_config      [expr {$ctrl_base + 0x28}]

set in_pixels [expr {$img_w * $img_h}]
set out_w [expr {$img_w * $scale}]
set out_h [expr {$img_h * $scale}]
set out_pixels [expr {$out_w * $out_h}]

proc try_target {filter label} {
    if {[catch {targets -set -filter $filter} err]} {
        puts "TINYSPAN_A53_COMPARE_TARGET_SELECT_FAIL_${label}=$err"
        return 0
    }
    puts "TINYSPAN_A53_COMPARE_TARGET_SELECT_PASS_${label}=1"
    return 1
}

proc select_access_target {label} {
    if {[try_target {name =~ "DAP"} "${label}_DAP"]} { return 1 }
    if {[try_target {name =~ "Cortex-A53 #0"} "${label}_A53_0"]} { return 1 }
    if {[try_target {name =~ "*Cortex-A53*#0*"} "${label}_A53_0_GLOB"]} { return 1 }
    if {[try_target {name =~ "PSU"} "${label}_PSU"]} { return 1 }
    return 0
}

proc read32 {addr} {
    set value [mrd -force -value $addr 1]
    return [expr {$value & 0xffffffff}]
}

proc write32 {addr value} {
    mwr $addr [expr {$value & 0xffffffff}]
}

proc align_up {value align} {
    return [expr {(($value + $align - 1) / $align) * $align}]
}

proc add_mem_region {addr size label} {
    if {[catch {memmap -addr $addr -size $size -flags 3} err]} {
        error [format "Failed to add XSCT memory map %s at 0x%08X size 0x%X: %s" $label $addr $size $err]
    }
    puts [format "TINYSPAN_A53_COMPARE_MEMMAP_%s=0x%08X+0x%X" $label $addr $size]
}

connect
catch {configparams force-mem-accesses 1}
after 1000
puts "TINYSPAN_A53_COMPARE_TARGETS_BEGIN"
targets
puts "TINYSPAN_A53_COMPARE_TARGETS_END"

if {[try_target {name =~ "PS TAP"} "PS_TAP"]} {
    catch {rst -system}
    after 3000
}

if {[try_target {name =~ "PSU"} "PSU"]} {
    source $psu_init_tcl
    puts "TINYSPAN_A53_COMPARE_PSU_INIT_SOURCE=$psu_init_tcl"
    psu_init
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
    puts "TINYSPAN_A53_COMPARE_PSU_INIT_PASS=1"
}

if {![select_access_target "ACCESS"]} {
    error "Could not select DAP, PSU, or A53 target for AXI/DDR access"
}

set ctrl_map_size 0x10000
set input_map_size [align_up [expr {$in_pixels * 4}] 0x1000]
set output_map_size [align_up [expr {$out_pixels * 4}] 0x1000]
set ref_map_size [align_up [expr {$out_pixels * 3}] 0x1000]
if {$input_map_size < 0x10000} { set input_map_size 0x10000 }
if {$output_map_size < 0x10000} { set output_map_size 0x10000 }
if {$ref_map_size < 0x10000} { set ref_map_size 0x10000 }
add_mem_region $ctrl_base $ctrl_map_size "CTRL_AXI_LITE"
add_mem_region $input_base $input_map_size "INPUT_DDR"
add_mem_region $output_base $output_map_size "OUTPUT_DDR"
add_mem_region $reference_base $ref_map_size "REFERENCE_DDR"

puts [format "TINYSPAN_A53_COMPARE_CTRL_BASE=0x%08X" $ctrl_base]
puts [format "TINYSPAN_A53_COMPARE_INPUT_BASE=0x%08X" $input_base]
puts [format "TINYSPAN_A53_COMPARE_OUTPUT_BASE=0x%08X" $output_base]
puts [format "TINYSPAN_A53_COMPARE_REFERENCE_BASE=0x%08X" $reference_base]
puts "TINYSPAN_A53_COMPARE_IMG_W=$img_w"
puts "TINYSPAN_A53_COMPARE_IMG_H=$img_h"
puts "TINYSPAN_A53_COMPARE_SCALE=$scale"
puts "TINYSPAN_A53_COMPARE_INPUT_PIXELS=$in_pixels"
puts "TINYSPAN_A53_COMPARE_OUTPUT_PIXELS=$out_pixels"
puts "TINYSPAN_A53_COMPARE_WAIT_MS=$wait_ms"
puts "TINYSPAN_A53_COMPARE_COMPARE_TIMEOUT_MS=$compare_timeout_ms"

write32 $reg_control 0x2
after 10
write32 $reg_img_w $img_w
write32 $reg_img_h $img_h
write32 $reg_input_base $input_base
write32 $reg_output_base $output_base
puts [format "TINYSPAN_A53_COMPARE_CONFIG=0x%08X" [read32 $reg_config]]
puts [format "TINYSPAN_A53_COMPARE_STATUS_AFTER_CLEAR=0x%08X" [read32 $reg_status]]

dow -data $input_words_bin $input_base
puts "TINYSPAN_A53_COMPARE_INPUT_DOW_DATA=$input_words_bin"
dow -data $reference_raw $reference_base
puts "TINYSPAN_A53_COMPARE_REFERENCE_DOW_DATA=$reference_raw"
dow -data $output_poison_words_bin $output_base
puts "TINYSPAN_A53_COMPARE_OUTPUT_POISON_DOW_DATA=$output_poison_words_bin"
flush stdout

puts "TINYSPAN_A53_COMPARE_START_WRITE_BEGIN=1"
flush stdout
write32 $reg_control 0x1
puts "TINYSPAN_A53_COMPARE_START_WRITE_DONE=1"
puts "TINYSPAN_A53_COMPARE_POST_START_FIXED_WAIT_MS=$wait_ms"
flush stdout
after $wait_ms

set frame_status [read32 $reg_status]
set frame_error [read32 $reg_error]
set cycles_lo [read32 $reg_frame_cycles_lo]
set cycles_hi [read32 $reg_frame_cycles_hi]
set tiles_done [read32 $reg_tiles_done]
set frame_cycles [expr {($cycles_hi * 4294967296) + $cycles_lo}]
puts [format "TINYSPAN_A53_COMPARE_FRAME_STATUS=0x%08X" $frame_status]
puts [format "TINYSPAN_A53_COMPARE_FRAME_ERROR=0x%08X" $frame_error]
puts [format "TINYSPAN_A53_COMPARE_FRAME_CYCLES_LO=0x%08X" $cycles_lo]
puts [format "TINYSPAN_A53_COMPARE_FRAME_CYCLES_HI=0x%08X" $cycles_hi]
puts "TINYSPAN_A53_COMPARE_FRAME_CYCLES=$frame_cycles"
puts "TINYSPAN_A53_COMPARE_TILES_DONE=$tiles_done"
flush stdout

if {![try_target {name =~ "Cortex-A53 #0"} "A53_0"]} {
    if {![try_target {name =~ "*Cortex-A53*#0*"} "A53_0_GLOB"]} {
        error "Could not select Cortex-A53 #0"
    }
}
catch {stop}
catch {rst -processor}
after 500
catch {stop}
dow $elf_path
puts "TINYSPAN_A53_COMPARE_DOW_ELF=$elf_path"
con
set compare_start [clock milliseconds]
set status 0x52554e20
while {([clock milliseconds] - $compare_start) < $compare_timeout_ms} {
    after 200
    set status [read32 $result_base]
    if {$status != 0x52554e20} {
        break
    }
}
catch {stop}

set status [read32 $result_base]
set mismatch_bytes [read32 [expr {$result_base + 4}]]
set total_bytes [read32 [expr {$result_base + 8}]]
set max_diff [read32 [expr {$result_base + 12}]]
set first_mismatch [read32 [expr {$result_base + 16}]]
set first_expected [read32 [expr {$result_base + 20}]]
set first_actual [read32 [expr {$result_base + 24}]]
set result_output_base [read32 [expr {$result_base + 28}]]
set result_reference_base [read32 [expr {$result_base + 32}]]
set result_pixels [read32 [expr {$result_base + 36}]]
set sample_count [read32 [expr {$result_base + 40}]]

puts [format "TINYSPAN_A53_COMPARE_STATUS=0x%08X" $status]
puts "TINYSPAN_A53_COMPARE_MISMATCH_BYTES=$mismatch_bytes"
puts "TINYSPAN_A53_COMPARE_TOTAL_BYTES=$total_bytes"
puts "TINYSPAN_A53_COMPARE_MAX_DIFF=$max_diff"
puts "TINYSPAN_A53_COMPARE_FIRST_MISMATCH_PIXEL=$first_mismatch"
puts [format "TINYSPAN_A53_COMPARE_FIRST_EXPECTED=0x%06X" $first_expected]
puts [format "TINYSPAN_A53_COMPARE_FIRST_ACTUAL=0x%06X" $first_actual]
puts [format "TINYSPAN_A53_COMPARE_RESULT_OUTPUT_BASE=0x%08X" $result_output_base]
puts [format "TINYSPAN_A53_COMPARE_RESULT_REFERENCE_BASE=0x%08X" $result_reference_base]
puts "TINYSPAN_A53_COMPARE_RESULT_PIXELS=$result_pixels"
puts "TINYSPAN_A53_COMPARE_SAMPLE_COUNT=$sample_count"

for {set i 0} {$i < $sample_count && $i < 8} {incr i} {
    set base [expr {$result_base + (32 + $i * 4) * 4}]
    set pix [read32 $base]
    set exp [read32 [expr {$base + 4}]]
    set act [read32 [expr {$base + 8}]]
    set dif [read32 [expr {$base + 12}]]
    puts [format "TINYSPAN_A53_COMPARE_SAMPLE_%02d_PIXEL=%d" $i $pix]
    puts [format "TINYSPAN_A53_COMPARE_SAMPLE_%02d_EXPECTED=0x%06X" $i $exp]
    puts [format "TINYSPAN_A53_COMPARE_SAMPLE_%02d_ACTUAL=0x%06X" $i $act]
    puts [format "TINYSPAN_A53_COMPARE_SAMPLE_%02d_DIFF=0x%06X" $i $dif]
}

if {$status != 0x50415353 || $mismatch_bytes != 0 || $max_diff != 0} {
    error "TinySPAN A53 frame compare failed"
}
puts "TINYSPAN_A53_COMPARE_PASS=1"
