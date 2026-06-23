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

在 Windows 上先在项目根目录生成参数和测试向量。命令示例:

```bat
gcc -O2 -o tools/gen_vectors.exe tools/gen_vectors.c
tools\gen_vectors.exe 附件\qc_peg_40_50_invc6dplopt_shift_inv.txt 120

py tools\gen_qc_params.py 附件\qc_peg_40_50_invc6dplopt_shift_inv.txt
```

这一步会生成:

```text
rtl/qc_params.vh
tv_in.txt
tv_gold_bits.txt
tv_gold_flags.txt
trace_gold.txt
```

### 方式 A: Vivado Tcl Shell 直接跑 xsim

打开 Vivado Tcl Shell，先进入项目根目录，再运行:

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

### 方式 B: Vivado GUI 工程里运行

如果你要在 Vivado GUI 的工程模式里跑，按下面顺序操作:

1. 打开 Vivado
2. 点击 `Create Project`
3. 新建一个空工程
4. 器件可以先任选一个常见 FPGA；这里跑的是行为级仿真，不影响功能验证
5. 工程打开后，找到底部的 `Tcl Console`
6. 先在项目根目录执行上面的 `gen_vectors.exe` 和 `gen_qc_params.py`
7. 然后在 `Tcl Console` 里执行:

```tcl
cd {D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计}
source rtl/add_to_vivado_project.tcl
```

上面这两条命令会把:

```text
rtl/bf_decoder_top.v
rtl/syndrome_calc.v
rtl/conflict_flip.v
rtl/bf_tb.v
```

加入 Vivado 工程，并设置仿真顶层为 `bf_tb`。

8. 在左侧 `Flow Navigator` 中点击:

```text
Simulation -> Run Simulation -> Run Behavioral Simulation
```

9. 仿真结束后，在 Vivado 控制台里检查是否打印:

```text
PASS: all 120 frames match
```

10. 再检查生成的:

```text
trace_rtl.txt
```

11. 最后与黄金轨迹比较:

```bat
fc trace_gold.txt trace_rtl.txt
```

### 如果 Vivado 报找不到 `tv_in.txt`

这是最常见的问题。`bf_tb.v` 里的 `$readmemb(...)` 默认按当前仿真工作目录找文件。

解决方法有两种。

方法 1: 直接把下面这些文本文件复制到 Vivado 仿真运行目录:

```text
tv_in.txt
tv_gold_bits.txt
tv_gold_flags.txt
```

方法 2: 在 Vivado 里给 xsim 传 plusargs，避免复制文件。示例:

```tcl
set_property xsim.simulate.xsim.more_options {\
    -testplusarg TV_IN=D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计/tv_in.txt \
    -testplusarg TV_GOLD_BITS=D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计/tv_gold_bits.txt \
    -testplusarg TV_GOLD_FLAGS=D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计/tv_gold_flags.txt \
    -testplusarg TRACE_RTL=D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计/trace_rtl.txt} [get_filesets sim_1]
```

设置完后，再点一次 `Run Behavioral Simulation`。

## Tcl 怎么运行

在 Vivado 里运行 Tcl 的方法就是:

1. 打开底部的 `Tcl Console`
2. 输入:

```tcl
source 文件路径
```

例如:

```tcl
cd {D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计}
source rtl/add_to_vivado_project.tcl
```

或者直接运行 xsim 脚本:

```tcl
cd {D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计}
source rtl/run_xsim.tcl
```

## 阈值说明

本码的列重实测为 3 和 4 混合，不是纯 4。因此翻转阈值使用自适应常数 `T=dv-1`: 列重 4 的比特阈值为 3，列重 3 的比特阈值为 2。
