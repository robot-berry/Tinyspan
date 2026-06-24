if {[llength $argv] < 2} {
    error "Usage: run_xsct_a53_ddr_alias_probe.tcl <psu_init.tcl> <elf>"
}

set psu_init_tcl [file normalize [lindex $argv 0]]
set elf_path [file normalize [lindex $argv 1]]
set result_base 0xFFFD8000

if {![file exists $psu_init_tcl]} {
    error "psu_init.tcl not found: $psu_init_tcl"
}
if {![file exists $elf_path]} {
    error "ELF not found: $elf_path"
}

proc try_target {filter label} {
    if {[catch {targets -set -filter $filter} err]} {
        puts "A53_DDR_ALIAS_TARGET_SELECT_FAIL_${label}=$err"
        return 0
    }
    puts "A53_DDR_ALIAS_TARGET_SELECT_PASS_${label}=1"
    return 1
}

proc read32 {addr} {
    set value [mrd -force -value $addr 1]
    return [expr {$value & 0xffffffff}]
}

connect
catch {configparams force-mem-accesses 1}
after 1000
puts "A53_DDR_ALIAS_TARGETS_BEGIN"
targets
puts "A53_DDR_ALIAS_TARGETS_END"

if {[try_target {name =~ "PS TAP"} "PS_TAP"]} {
    catch {rst -system}
    after 3000
}

if {[try_target {name =~ "PSU"} "PSU"]} {
    source $psu_init_tcl
    puts "A53_DDR_ALIAS_PSU_INIT_SOURCE=$psu_init_tcl"
    psu_init
    psu_ps_pl_isolation_removal
    psu_ps_pl_reset_config
    puts "A53_DDR_ALIAS_PSU_INIT_PASS=1"
}

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
puts "A53_DDR_ALIAS_DOW_ELF=$elf_path"
con
after 1000
catch {stop}

set status [read32 $result_base]
set mismatches [read32 [expr {$result_base + 4}]]
set base [read32 [expr {$result_base + 8}]]
set stride [read32 [expr {$result_base + 12}]]
set count [read32 [expr {$result_base + 16}]]

puts [format "A53_DDR_ALIAS_STATUS=0x%08X" $status]
puts "A53_DDR_ALIAS_MISMATCHES=$mismatches"
puts [format "A53_DDR_ALIAS_BASE=0x%08X" $base]
puts [format "A53_DDR_ALIAS_STRIDE=0x%08X" $stride]
puts "A53_DDR_ALIAS_COUNT=$count"

for {set i 0} {$i < $count} {incr i} {
    set expected [read32 [expr {$result_base + 32 + $i * 4}]]
    set actual [read32 [expr {$result_base + 64 + $i * 4}]]
    puts [format "A53_DDR_ALIAS_EXPECTED_%02d=0x%08X" $i $expected]
    puts [format "A53_DDR_ALIAS_ACTUAL_%02d=0x%08X" $i $actual]
}

if {$status != 0x50415353 || $mismatches != 0} {
    error "A53 DDR alias probe failed"
}
puts "A53_DDR_ALIAS_PASS=1"
