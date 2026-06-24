if {[llength $argv] < 4} {
    error "Usage: run_xsct_ps_ddr_alias_probe.tcl <psu_init.tcl> <base_addr> <stride_bytes> <count>"
}

set psu_init_tcl [file normalize [lindex $argv 0]]
set base_addr [lindex $argv 1]
set stride_bytes [expr {int([lindex $argv 2])}]
set count [expr {int([lindex $argv 3])}]

if {![file exists $psu_init_tcl]} {
    error "psu_init.tcl not found: $psu_init_tcl"
}
if {$stride_bytes <= 0 || $count <= 1} {
    error "invalid stride/count"
}

proc try_target {filter label} {
    if {[catch {targets -set -filter $filter} err]} {
        puts "PS_DDR_ALIAS_TARGET_SELECT_FAIL_${label}=$err"
        return 0
    }
    puts "PS_DDR_ALIAS_TARGET_SELECT_PASS_${label}=1"
    return 1
}

proc select_access_target {label} {
    if {[try_target {name =~ "DAP"} "${label}_DAP"]} {
        return 1
    }
    if {[try_target {name =~ "Cortex-A53 #0"} "${label}_A53_0"]} {
        catch {stop}
        catch {rst -processor}
        catch {stop}
        return 1
    }
    if {[try_target {name =~ "*Cortex-A53*#0*"} "${label}_A53_0_GLOB"]} {
        catch {stop}
        catch {rst -processor}
        catch {stop}
        return 1
    }
    if {[try_target {name =~ "PSU"} "${label}_PSU"]} {
        return 1
    }
    return 0
}

proc read32 {addr} {
    set value [mrd -force -value $addr 1]
    return [expr {$value & 0xffffffff}]
}

proc write32 {addr value} {
    mwr -force $addr [expr {$value & 0xffffffff}]
}

proc align_up {value align} {
    return [expr {(($value + $align - 1) / $align) * $align}]
}

connect
catch {configparams force-mem-accesses 1}
after 1000
puts "PS_DDR_ALIAS_TARGETS_BEGIN"
targets
puts "PS_DDR_ALIAS_TARGETS_END"

if {[try_target {name =~ "PS TAP"} "PS_TAP"]} {
    catch {rst -system}
    after 3000
}

if {[try_target {name =~ "PSU"} "PSU"]} {
    source $psu_init_tcl
    puts "PS_DDR_ALIAS_PSU_INIT_SOURCE=$psu_init_tcl"
    psu_init
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
    puts "PS_DDR_ALIAS_PSU_INIT_PASS=1"
}

if {![select_access_target "ACCESS"]} {
    error "Could not select DAP/PSU/A53 target for DDR accesses"
}

set span [expr {$stride_bytes * $count}]
set map_size [align_up $span 0x1000]
if {$map_size < 0x10000} {
    set map_size 0x10000
}
if {[catch {memmap -addr $base_addr -size $map_size -flags 3} err]} {
    error [format "memmap failed at 0x%08X size 0x%X: %s" $base_addr $map_size $err]
}

puts [format "PS_DDR_ALIAS_BASE=0x%08X" $base_addr]
puts [format "PS_DDR_ALIAS_STRIDE_BYTES=0x%X" $stride_bytes]
puts "PS_DDR_ALIAS_COUNT=$count"
puts [format "PS_DDR_ALIAS_MAP_SIZE=0x%X" $map_size]

for {set i 0} {$i < $count} {incr i} {
    set addr [expr {$base_addr + $i * $stride_bytes}]
    set value [expr {0xA5000000 | (($i & 0xff) << 8) | ($i & 0xff)}]
    write32 $addr $value
    puts [format "PS_DDR_ALIAS_WRITE_%02d_ADDR=0x%08X" $i $addr]
    puts [format "PS_DDR_ALIAS_WRITE_%02d_VALUE=0x%08X" $i $value]
}

set mismatches 0
for {set i 0} {$i < $count} {incr i} {
    set addr [expr {$base_addr + $i * $stride_bytes}]
    set expected [expr {0xA5000000 | (($i & 0xff) << 8) | ($i & 0xff)}]
    set actual [read32 $addr]
    puts [format "PS_DDR_ALIAS_READ_%02d_ADDR=0x%08X" $i $addr]
    puts [format "PS_DDR_ALIAS_READ_%02d_EXPECTED=0x%08X" $i $expected]
    puts [format "PS_DDR_ALIAS_READ_%02d_ACTUAL=0x%08X" $i $actual]
    if {$actual != $expected} {
        incr mismatches
    }
}

puts "PS_DDR_ALIAS_MISMATCHES=$mismatches"
if {$mismatches != 0} {
    error "PS DDR alias probe failed"
}
puts "PS_DDR_ALIAS_PASS=1"
