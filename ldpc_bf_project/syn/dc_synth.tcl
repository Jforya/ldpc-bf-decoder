# dc_synth.tcl — 阶段三 Design Compiler 综合脚本 (ASIC路径)
# 用法: dc_shell -f dc_synth.tcl
# 工艺库按实际环境替换(示例为通用占位); 报告中需注明库名与目标频率

# ---- 工艺库设置(替换为实际库) ----
set search_path    ". /path/to/your/std_cell_lib/db"
set target_library "your_lib_tt_1p0v_25c.db"
set link_library   "* $target_library"

set TOP bf_decoder_top
read_verilog [glob ./rtl/*.v]
current_design $TOP
link

# ---- 约束: 目标 200 MHz (5 ns), 按工艺调整 ----
create_clock -name clk -period 5.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay  1.0 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 1.0 -clock clk [all_outputs]

compile_ultra

# ---- 报告: 任务书6.2要求 ----
report_area      -hierarchy        > rpt_area.txt
report_timing    -max_paths 10     > rpt_timing.txt
report_power     -hierarchy        > rpt_power.txt
report_qor                         > rpt_qor.txt

# 分析提示(写报告用):
#  - 面积大头: x寄存器(2000 FF) + decoded_bits(2000 FF) + 冲突计数加法器阵列
#  - 关键路径: x -> syndrome XOR -> rotate -> adder -> compare -> XOR -> x
#  - 若时序不满足: 在syndrome后插流水寄存器, 每轮2周期, 频率约提升一倍
write -format verilog -hierarchy -output bf_decoder_netlist.v
exit
