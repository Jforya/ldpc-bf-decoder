# Run from the project root in Vivado Tcl Shell:
#   cd /path/to/LDPC_比特翻转算法实现和译码器硬件设计
#   source rtl/run_xsim.tcl

xvlog -sv -i rtl \
    rtl/bf_decoder_top.v \
    rtl/syndrome_calc.v \
    rtl/conflict_flip.v \
    rtl/bf_tb.v

xelab bf_tb -debug typical -s bf_tb_sim
xsim bf_tb_sim -runall
