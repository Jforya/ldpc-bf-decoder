# Run from the project root in Vivado Tcl Shell:
#   cd /path/to/LDPC_比特翻转算法实现和译码器硬件设计
#   source rtl/run_xsim.tcl

set root_dir [file normalize [pwd]]
set tv_in        [file join $root_dir tv_in.txt]
set tv_gold_bits [file join $root_dir tv_gold_bits.txt]
set tv_gold_flags [file join $root_dir tv_gold_flags.txt]
set trace_rtl    [file join $root_dir trace_rtl.txt]

xvlog -sv -i rtl \
    rtl/bf_decoder_top.v \
    rtl/syndrome_calc.v \
    rtl/conflict_flip.v \
    rtl/bf_tb.v

xelab bf_tb -debug typical -s bf_tb_sim
xsim bf_tb_sim -runall \
    -testplusarg TV_IN=$tv_in \
    -testplusarg TV_GOLD_BITS=$tv_gold_bits \
    -testplusarg TV_GOLD_FLAGS=$tv_gold_flags \
    -testplusarg TRACE_RTL=$trace_rtl
