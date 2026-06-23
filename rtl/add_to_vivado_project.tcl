# Use inside an opened Vivado project:
#   source rtl/add_to_vivado_project.tcl
#
# This script adds RTL/testbench sources to the current project and
# sets include directories/top module for simulation.

set script_dir [file dirname [file normalize [info script]]]
set root_dir   [file normalize [file join $script_dir ..]]

set rtl_srcs [list \
    [file join $root_dir rtl bf_decoder_top.v] \
    [file join $root_dir rtl syndrome_calc.v] \
    [file join $root_dir rtl conflict_flip.v]]

set tb_srcs [list \
    [file join $root_dir rtl bf_tb.v]]

add_files -norecurse -fileset sources_1 $rtl_srcs
add_files -norecurse -fileset sim_1     $rtl_srcs
add_files -norecurse -fileset sim_1     $tb_srcs

set_property include_dirs [list [file join $root_dir rtl]] [get_filesets sources_1]
set_property include_dirs [list [file join $root_dir rtl]] [get_filesets sim_1]
set_property top bf_tb [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
