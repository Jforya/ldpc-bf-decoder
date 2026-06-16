# vivado_synth.tcl — 阶段三 Vivado 综合脚本
# 用法: vivado -mode batch -source vivado_synth.tcl
# 器件可按手头开发板修改; xc7a200t (Artix-7) 资源足够容纳全并行译码器

set PART xc7a200tfbg676-2
set TOP  bf_decoder_top

create_project -in_memory -part $PART
read_verilog [glob ./rtl/*.v]
# qc_params.vh 通过 `include 引入, 确保在 include 搜索路径中
set_property include_dirs ./rtl [current_fileset]

read_xdc ./constraints.xdc

synth_design -top $TOP -part $PART

# ---- 报告: 任务书6.1要求的四类 ----
report_utilization      -file rpt_utilization.txt          ;# LUT / FF / BRAM / DSP
report_timing_summary   -file rpt_timing.txt               ;# WNS / TNS
report_power            -file rpt_power.txt                ;# 功耗估计
report_methodology      -file rpt_methodology.txt          ;# critical warning 排查

# 可选: 走完实现流程获得更准的时序/功耗
# opt_design; place_design; route_design
# report_timing_summary -file rpt_timing_routed.txt
# report_power          -file rpt_power_routed.txt
puts "Synthesis done. See rpt_*.txt"
