# QC-LDPC BF RTL

## 文件清单

- `tools/gen_qc_params.py`: 读取基矩阵并生成 `rtl/qc_params.vh`
- `tools/gen_vectors.c`: 生成 120 帧 RTL 对拍向量和 C 黄金逐轮轨迹
- `rtl/qc_params.vh`: QC 连接常数表，包含 `ROWCONN`、`COLCONN`、`COLDEG`
- `rtl/syndrome_calc.v`: 组合计算 `syndrome = H*x mod 2`
- `rtl/conflict_flip.v`: 组合计算冲突数并输出同步翻转掩码
- `rtl/bf_decoder_top.v`: IDLE/RUN FSM 和 `x` 寄存器
- `rtl/bf_tb.v`: 读取测试向量，逐帧比对输出，并生成 `trace_rtl.txt`

## 仿真步骤

在项目根目录运行:

```sh
gcc -O2 -o tools/gen_vectors tools/gen_vectors.c
./tools/gen_vectors 附件/qc_peg_40_50_invc6dplopt_shift_inv.txt 120

python3 tools/gen_qc_params.py 附件/qc_peg_40_50_invc6dplopt_shift_inv.txt

iverilog -g2012 -I rtl -o sim \
  rtl/bf_decoder_top.v rtl/syndrome_calc.v rtl/conflict_flip.v rtl/bf_tb.v
vvp sim

diff trace_gold.txt trace_rtl.txt
```

期望结果:

```text
PASS: all 120 frames match
```

并且 `diff trace_gold.txt trace_rtl.txt` 没有输出。

## Windows Vivado xsim 步骤

在 Windows 上建议仍然先在项目根目录生成参数和测试向量。命令示例:

```bat
gcc -O2 -o tools/gen_vectors.exe tools/gen_vectors.c
tools\gen_vectors.exe 附件\qc_peg_40_50_invc6dplopt_shift_inv.txt 120

py tools\gen_qc_params.py 附件\qc_peg_40_50_invc6dplopt_shift_inv.txt
```

然后打开 Vivado Tcl Shell，先进入项目根目录，再运行:

```tcl
cd {D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计}
source rtl/run_xsim.tcl
```

仿真结束后，检查 Vivado 控制台是否打印:

```text
PASS: all 120 frames match
```

再用 Windows 命令比较逐轮轨迹:

```bat
fc trace_gold.txt trace_rtl.txt
```

如果 `fc` 报告没有差异，则说明 RTL 与 C 黄金模型逐轮逐位一致。

## 阈值说明

本码的列重实测为 3 和 4 混合，不是纯 4。因此翻转阈值使用自适应常数 `T=dv-1`: 列重 4 的比特阈值为 3，列重 3 的比特阈值为 2。
