# QC-LDPC Multi-bit BF 译码器项目

## 复现步骤
1. 阶段一: `gcc -O2 -o bf_sim bf_sim.c && ./bf_sim curve base.txt`  -> fer_curve.csv
2. 生成RTL参数与测试向量:
   `python3 gen_qc_params.py base.txt && mv qc_params.vh rtl/`
   `./bf_sim vectors base.txt 120`  -> tv_*.txt, trace_gold.txt
3. 阶段二仿真 (在rtl/目录, 把tv_*.txt拷入):
   `iverilog -g2012 -o sim bf_decoder_top.v syndrome_calc.v conflict_flip.v bf_tb.v && vvp sim`
   逐轮轨迹比对: `diff trace_gold.txt trace_rtl.txt`
4. 阶段三: `vivado -mode batch -source syn/vivado_synth.tcl` 或 `dc_shell -f syn/dc_synth.tcl`

已验证结果: 120/120帧一致, 504个迭代快照逐位一致;
yosys综合: 10701 LUT6 / 4015 FF / 0 BRAM / 0 DSP, 最长路径9级LUT。
