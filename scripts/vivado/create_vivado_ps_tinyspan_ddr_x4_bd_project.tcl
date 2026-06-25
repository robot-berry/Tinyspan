set script_dir [file normalize [file dirname [info script]]]
if {[file tail $script_dir] eq "vivado"} {
    set origin_dir [file normalize [file join $script_dir .. ..]]
} else {
    set origin_dir [file normalize [file join $script_dir ..]]
}

set vivado_dir [file join $origin_dir vivado]
set proj_dir   [file join $vivado_dir ps_tinyspan_ddr_x4]
set bd_name    pstinyspanx4ddr
set part_name  xczu19eg-ffvc1760-2-i

if {[info exists ::env(PS_TINYSPAN_DDR_X4_PROJECT_DIR)]} {
    set proj_dir [file normalize $::env(PS_TINYSPAN_DDR_X4_PROJECT_DIR)]
}
if {[info exists ::env(PS_TINYSPAN_DDR_X4_PART)]} {
    set part_name $::env(PS_TINYSPAN_DDR_X4_PART)
}

set img_w 320
set img_h 180
set tile_w 32
set tile_h 32
set scale 4
set pl_freq_mhz 150
set input_base 0x10000000
set output_base 0x11000000
set m_axi_data_w 32
set use_serial_base 0

foreach {env_name var_name} {
  PS_TINYSPAN_DDR_X4_IMG_W img_w
  PS_TINYSPAN_DDR_X4_IMG_H img_h
  PS_TINYSPAN_DDR_X4_TILE_W tile_w
  PS_TINYSPAN_DDR_X4_TILE_H tile_h
  PS_TINYSPAN_DDR_X4_SCALE scale
  PS_TINYSPAN_DDR_X4_PL_FREQ_MHZ pl_freq_mhz
  PS_TINYSPAN_DDR_X4_INPUT_BASE input_base
  PS_TINYSPAN_DDR_X4_OUTPUT_BASE output_base
  PS_TINYSPAN_DDR_X4_M_AXI_DATA_W m_axi_data_w
  PS_TINYSPAN_DDR_X4_USE_SERIAL_BASE use_serial_base
} {
  if {[info exists ::env($env_name)]} {
    set $var_name $::env($env_name)
  }
}

file mkdir $vivado_dir
file delete -force $proj_dir

create_project ps_tinyspan_ddr_x4 $proj_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property xpm_libraries {XPM_MEMORY} [current_project]

set span_dir  [file join $origin_dir rtl tinyspan_core]
set board_dir [file join $origin_dir rtl board_wrapper]

proc add_required_file {path} {
    if {![file exists $path]} {
        error "Required RTL file not found: $path"
    }
    add_files -fileset sources_1 $path
}

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
    add_required_file $src
}
update_compile_order -fileset sources_1

proc apply_ps_ddr_reference_config {ps_cell ref_tcl} {
    if {![file exists $ref_tcl]} {
        puts "PS_TINYSPAN_DDR_X4_DDR_REF_STATUS=missing $ref_tcl"
        return 0
    }

    set fp [open $ref_tcl r]
    set lines [split [read $fp] "\n"]
    close $fp

    set in_ps_dict 0
    set props [list]
    foreach line $lines {
        if {[regexp {set_property -dict \[ list} $line]} {
            set in_ps_dict 1
            continue
        }
        if {!$in_ps_dict} {
            continue
        }
        if {[regexp {\] \$zynq_ultra_ps_e_0} $line]} {
            break
        }

        set key ""
        set value ""
        if {[regexp {^\s*(CONFIG\.(PSU__DDRC__|PSU__DDR|PSU__CRF_APB__DDR|PSU__USE__DDR)[^ ]*)\s+\{(.*)\}\s*\\?\s*$} $line -> key _ value] ||
            [regexp {^\s*(CONFIG\.SUBPRESET1)\s+\{(.*)\}\s*\\?\s*$} $line -> key value]} {
            lappend props $key $value
        }
    }

    if {[llength $props] == 0} {
        error "No PS DDR reference properties extracted from $ref_tcl"
    }

    set_property -dict $props $ps_cell
    puts "PS_TINYSPAN_DDR_X4_DDR_REF_STATUS=applied"
    puts "PS_TINYSPAN_DDR_X4_DDR_REF_TCL=$ref_tcl"
    puts "PS_TINYSPAN_DDR_X4_DDR_REF_PROPERTY_PAIRS=[expr {[llength $props] / 2}]"
    return 1
}

create_bd_design $bd_name
current_bd_design $bd_name

set ps [create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:* ps]
set_property -dict [list \
  CONFIG.PSU__FPGA_PL0_ENABLE {1} \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $pl_freq_mhz \
  CONFIG.PSU__CRL_APB__PL0_REF_CTRL__SRCSEL {IOPLL} \
  CONFIG.PSU__USE__FABRIC__RST {1} \
  CONFIG.PSU__USE__M_AXI_GP0 {1} \
  CONFIG.PSU__USE__M_AXI_GP1 {0} \
  CONFIG.PSU__USE__M_AXI_GP2 {0} \
  CONFIG.PSU__USE__S_AXI_GP0 {0} \
  CONFIG.PSU__USE__S_AXI_GP1 {0} \
  CONFIG.PSU__USE__S_AXI_GP2 {1} \
  CONFIG.PSU__USE__S_AXI_GP3 {0} \
  CONFIG.PSU__USE__S_AXI_GP4 {0} \
  CONFIG.PSU__USE__S_AXI_GP5 {0} \
  CONFIG.PSU__USE__S_AXI_GP6 {0} \
  CONFIG.PSU__USE__IRQ0 {0} \
  CONFIG.PSU__SD1__PERIPHERAL__ENABLE {1} \
  CONFIG.PSU__SD1__PERIPHERAL__IO {MIO 46 .. 51} \
  CONFIG.PSU__SD1__DATA_TRANSFER_MODE {4Bit} \
  CONFIG.PSU__SD1__GRP_CD__ENABLE {1} \
  CONFIG.PSU__SD1__GRP_CD__IO {MIO 45} \
  CONFIG.PSU__SD1__GRP_WP__ENABLE {1} \
  CONFIG.PSU__SD1__GRP_WP__IO {MIO 44} \
  CONFIG.PSU__SD1__SLOT_TYPE {SD 2.0} \
  CONFIG.PSU__SD1__RESET__ENABLE {0} \
  CONFIG.PSU__SD1__GRP_POW__ENABLE {0} \
  CONFIG.PSU_SD1_INTERNAL_BUS_WIDTH {4} \
  CONFIG.SD1_BOARD_INTERFACE {custom} \
] $ps

set ps_ref_bd_tcl [file normalize [file join $origin_dir .. docs reference_face_zussd zcu106_hpc0_dual_bd.tcl]]
if {[info exists ::env(PS_TINYSPAN_DDR_X4_PS_REF_BD_TCL)]} {
    set ps_ref_bd_tcl [file normalize $::env(PS_TINYSPAN_DDR_X4_PS_REF_BD_TCL)]
}
set apply_ps_ref_ddr 1
if {[info exists ::env(PS_TINYSPAN_DDR_X4_APPLY_PS_REF_DDR)]} {
    set apply_ps_ref_ddr $::env(PS_TINYSPAN_DDR_X4_APPLY_PS_REF_DDR)
}
if {$apply_ps_ref_ddr ne "0"} {
    apply_ps_ddr_reference_config $ps $ps_ref_bd_tcl
} else {
    puts "PS_TINYSPAN_DDR_X4_DDR_REF_STATUS=disabled"
}

set ctrl_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* ctrl_ic]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $ctrl_ic

set mem_ic [create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:* mem_ic]
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {1}] $mem_ic

set rst [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:* rst]

set sr [create_bd_cell -type module -reference sr_ddr_tinyspan_x4_tile_writer_endpoint sr0]
set_property -dict [list \
  CONFIG.C_S_AXI_ADDR_WIDTH {8} \
  CONFIG.M_AXI_DATA_WIDTH $m_axi_data_w \
  CONFIG.DEFAULT_IMG_W $img_w \
  CONFIG.DEFAULT_IMG_H $img_h \
  CONFIG.DEFAULT_INPUT_BASE $input_base \
  CONFIG.DEFAULT_OUTPUT_BASE $output_base \
  CONFIG.TILE_W $tile_w \
  CONFIG.TILE_H $tile_h \
  CONFIG.SCALE $scale \
  CONFIG.BYTES_PER_PIXEL {4} \
  CONFIG.USE_SERIAL_BASE $use_serial_base \
] $sr

connect_bd_intf_net [get_bd_intf_pins ps/M_AXI_HPM0_FPD] [get_bd_intf_pins ctrl_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins ctrl_ic/M00_AXI] [get_bd_intf_pins sr0/s_axi]

connect_bd_intf_net [get_bd_intf_pins sr0/m_axi] [get_bd_intf_pins mem_ic/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins mem_ic/M00_AXI] [get_bd_intf_pins ps/S_AXI_HP0_FPD]

connect_bd_net [get_bd_pins ps/pl_clk0] \
  [get_bd_pins ps/maxihpm0_fpd_aclk] \
  [get_bd_pins ps/saxihp0_fpd_aclk] \
  [get_bd_pins ctrl_ic/ACLK] \
  [get_bd_pins ctrl_ic/S00_ACLK] \
  [get_bd_pins ctrl_ic/M00_ACLK] \
  [get_bd_pins mem_ic/ACLK] \
  [get_bd_pins mem_ic/S00_ACLK] \
  [get_bd_pins mem_ic/M00_ACLK] \
  [get_bd_pins rst/slowest_sync_clk] \
  [get_bd_pins sr0/s_axi_aclk] \
  [get_bd_pins sr0/m_axi_aclk]

connect_bd_net [get_bd_pins ps/pl_resetn0] [get_bd_pins rst/ext_reset_in]
connect_bd_net [get_bd_pins rst/peripheral_aresetn] \
  [get_bd_pins ctrl_ic/S00_ARESETN] \
  [get_bd_pins ctrl_ic/M00_ARESETN] \
  [get_bd_pins mem_ic/S00_ARESETN] \
  [get_bd_pins mem_ic/M00_ARESETN] \
  [get_bd_pins sr0/s_axi_aresetn] \
  [get_bd_pins sr0/m_axi_aresetn]
connect_bd_net [get_bd_pins rst/interconnect_aresetn] \
  [get_bd_pins ctrl_ic/ARESETN] \
  [get_bd_pins mem_ic/ARESETN]

assign_bd_address

set sr_ctrl_seg [get_bd_addr_segs -quiet sr0/s_axi/*]
if {[llength $sr_ctrl_seg] > 0} {
  assign_bd_address -offset 0xA0000000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces ps/Data] [lindex $sr_ctrl_seg 0] -force
}

set hp0_ddr_seg [get_bd_addr_segs -quiet ps/SAXIGP2/HP0_DDR_LOW]
if {[llength $hp0_ddr_seg] > 0} {
  assign_bd_address -offset 0x00000000 -range 0x80000000 \
    -target_address_space [get_bd_addr_spaces sr0/m_axi] [lindex $hp0_ddr_seg 0] -force
}

validate_bd_design
save_bd_design

set bd_file [get_files [file join $proj_dir ps_tinyspan_ddr_x4.srcs sources_1 bd $bd_name ${bd_name}.bd]]
catch { set_property synth_checkpoint_mode None $bd_file }
catch { set_property generate_synth_checkpoint false $bd_file }

make_wrapper -files $bd_file -top
add_files -norecurse [file join $proj_dir ps_tinyspan_ddr_x4.gen sources_1 bd $bd_name hdl ${bd_name}_wrapper.v]
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

puts "PASS create_vivado_ps_tinyspan_ddr_x4_bd_project"
puts "PS_TINYSPAN_DDR_X4_PROJECT=[file join $proj_dir ps_tinyspan_ddr_x4.xpr]"
puts "PS_TINYSPAN_DDR_X4_BD=$bd_file"
puts "PS_TINYSPAN_DDR_X4_CTRL_BASE=0xA0000000"
puts "PS_TINYSPAN_DDR_X4_INPUT_BASE=$input_base"
puts "PS_TINYSPAN_DDR_X4_OUTPUT_BASE=$output_base"
puts "PS_TINYSPAN_DDR_X4_IMG_W=$img_w"
puts "PS_TINYSPAN_DDR_X4_IMG_H=$img_h"
puts "PS_TINYSPAN_DDR_X4_TILE_W=$tile_w"
puts "PS_TINYSPAN_DDR_X4_TILE_H=$tile_h"
puts "PS_TINYSPAN_DDR_X4_SCALE=$scale"
puts "PS_TINYSPAN_DDR_X4_PL_FREQ_MHZ=$pl_freq_mhz"
puts "PS_TINYSPAN_DDR_X4_DATA_PATH=PS DDR -> HP0 -> TinySPAN DDR endpoint M_AXI -> DDR"
puts "PS_TINYSPAN_DDR_X4_DDR_POLICY=use ZynqMP PS DDR controller IP; no custom DDR controller or PHY"
