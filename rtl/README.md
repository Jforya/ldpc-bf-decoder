# QC-LDPC BF RTL

## 文件清单

| 文件 | 功能 | 核心原理 |
|------|------|---------|
| `tools/gen_qc_params.py` | 参数生成脚本 | 读取基矩阵，编译为 RTL 可用的连接常数表 |
| `tools/gen_vectors.c` | C 黄金模型 | 稀疏连接表 + 同步翻转 + 自适应阈值 T=dv-1 |
| `rtl/qc_params.vh` | 连接常数表 | `ROWCONN`、`COLCONN`、`COLDEG`，综合后变成纯布线 |
| `rtl/syndrome_calc.v` | 校验子计算 s=Hx | QC 循环右移 → XOR 树（行重≤6） |
| `rtl/conflict_flip.v` | 冲突计数 + 翻转 | QC 循环左移 → 3bit 加法 → 阈值比较 |
| `rtl/bf_decoder_top.v` | 顶层 FSM | IDLE→RUN，三出口：全零成功/翻满失败/无翻转失败 |
| `rtl/bf_tb.v` | 一致性验证 | `$readmemb` 读入 → 逐帧驱动 → 三项比对 + 逐轮快照 |

---

## 译码算法语义（RTL 和 C 模型一致）

1. x = 接收硬判决序列
2. 计算 s = H × x (mod 2)，若 s 全 0 → **成功**
3. 对每比特 j，统计它参与的校验中不满足的个数 conflict[j]
4. **同步翻转**所有 conflict[j] ≥ T[j] 的比特，其中 T[j] = 列重 dv[j] - 1
5. 若本轮无比特翻转 → **提前失败**
6. 重复 2-5，最多 MAX_ITER=50 轮

---

## 方式一：命令行快速仿真 (iverilog, 推荐用于快速验证)

在项目根目录运行:

### 1. 编译 C 程序，生成测试向量

```sh
gcc -O2 -o tools/gen_vectors tools/gen_vectors.c
./tools/gen_vectors 附件/qc_peg_40_50_invc6dplopt_shift_inv.txt 120
```

每部分含义：
- `gcc -O2 -o tools/gen_vectors` — 用 O2 优化编译 C 黄金模型，输出到 `tools/gen_vectors`
- `./tools/gen_vectors 附件/...txt 120` — 用基矩阵生成 120 帧测试数据，包含无错帧、单错帧、多错帧、BSC 随机错帧四种混合场景

输出文件：
- `tv_in.txt` — 每行 2000 个 '0'/'1'，加噪后的接收序列，作为 RTL 的输入激励
- `tv_gold_bits.txt` — 每行 2000 个 '0'/'1'，C 模型译码结果，作为"标准答案"
- `tv_gold_flags.txt` — 每行 8 位二进制 `{success, iter_count[6:0]}`，记录每帧是否成功 + 用了多少轮
- `trace_gold.txt` — 每轮翻转后的码字快照，格式 `F<帧号> I<轮号> <2000bit>`，用于逐轮逐比特对比

### 2. 生成 RTL 参数文件

```sh
python3 tools/gen_qc_params.py 附件/qc_peg_40_50_invc6dplopt_shift_inv.txt
```

这一步做了什么：
- 基矩阵（40×50）里的元素是循环移位值 s，RTL 里需要知道每个校验方程连接了哪些比特
- 脚本把基矩阵预编译成 Verilog 可直接使用的常数表，写入 `rtl/qc_params.vh`：
  - `ROWCONN` — 行连接表，syndrome_calc 用（1600 行，每行最多 6 个连接块）
  - `COLCONN` — 列连接表，conflict_flip 用（2000 列，每列最多 4 个连接块）
  - `COLDEG` — 每列列重（3 或 4），推导出自适应阈值 T = dv-1
- 因为 QC 结构里移位量都是常数，综合后这些"旋转"变成纯布线，不消耗逻辑

### 3. 用 iverilog 编译并仿真

```sh
iverilog -g2012 -I rtl -o sim \
  rtl/bf_decoder_top.v rtl/syndrome_calc.v rtl/conflict_flip.v rtl/bf_tb.v
vvp sim
```

每部分含义：
| 参数 | 含义 |
|------|------|
| `-g2012` | 使用 Verilog-2012 标准（generate、localparam 等语法需要） |
| `-I rtl` | include 搜索路径，让 iverilog 在 `rtl/` 下找到 `qc_params.vh` |
| `-o sim` | 输出可执行文件名为 `sim` |
| `bf_decoder_top.v` | 顶层：FSM 状态机 + 数据通路连线 |
| `syndrome_calc.v` | 计算 s = H×x (mod 2)，利用 QC 循环移位实现 |
| `conflict_flip.v` | 统计每比特冲突数 + 同步翻转判决 |
| `bf_tb.v` | testbench：逐帧驱动、三项比对、写 trace_rtl.txt |

仿真通过后会打印 `PASS: all 120 frames match golden model`。

### 4. 逐轮轨迹比对（最严格验证）

```sh
diff trace_gold.txt trace_rtl.txt
```

这一步做了什么：
- C 模型（`trace_gold.txt`）和 RTL 仿真（`trace_rtl.txt`）各自记录了每轮翻转后的码字
- `diff` 逐行比较两个文件，如果**输出为空**，说明所有迭代快照逐位完全一致
- 这是任务书要求的最高级别验证——不是只看最终结果，而是每一轮中间状态都对
- 如果有差异，看第一个分叉出现在第几帧第几轮第几位，直接定位到对应模块

期望结果:

```text
PASS: all 120 frames match
```

并且 `diff trace_gold.txt trace_rtl.txt` 没有输出。

---

## 方式二：Windows Vivado 仿真 + 综合

在 Windows 上先在项目根目录生成参数和测试向量。**在 Git Bash 或 PowerShell 中**:

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

### 方式 A: Vivado Tcl Shell 直接跑 xsim（最快）

打开 Vivado Tcl Shell（开始菜单 → Vivado → Vivado Tcl Shell），先进入项目根目录，再运行:

```tcl
cd {D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计}
source rtl/run_xsim.tcl
```

`run_xsim.tcl` 做了什么：
- 自动创建临时 Vivado 工程
- 添加所有 RTL 源文件和 testbench
- 设置 include 路径让 `qc_params.vh` 可被找到
- 启动 xsim 行为仿真
- 仿真结果打印在 Vivado 控制台

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
4. 器件选 **xc7a200tfbg676-2**（Artix-7，和综合脚本一致）
5. 工程打开后，先在项目根目录执行上面的 `gen_vectors.exe` 和 `gen_qc_params.py`
6. 在底部 `Tcl Console` 里执行:

```tcl
cd {D:/your/path/LDPC_比特翻转算法实现和译码器硬件设计}
source rtl/add_to_vivado_project.tcl
```

`add_to_vivado_project.tcl` 做了什么：
- 把 `bf_decoder_top.v`、`syndrome_calc.v`、`conflict_flip.v` 加入 Design Sources
- 把 `bf_tb.v` 加入 Simulation Sources 并设为顶层
- 设置 include 路径指向 `rtl/` 目录
- 设置仿真运行目录为项目根目录（让 `$readmemb` 能找到 `tv_*.txt`）

7. 在左侧 `Flow Navigator` 中点击:

```text
Simulation -> Run Simulation -> Run Behavioral Simulation
```

8. 仿真结束后，在 Vivado 控制台里检查是否打印:

```text
PASS: all 120 frames match
```

9. 再检查生成的 `trace_rtl.txt`

10. 最后与黄金轨迹比较:

```bat
fc trace_gold.txt trace_rtl.txt
```

### 如果 Vivado 报找不到 `tv_in.txt`

这是最常见的问题。`bf_tb.v` 里的 `$readmemb(...)` 默认按当前仿真工作目录找文件。

解决方法：直接把下面这些文本文件复制到 Vivado 仿真运行目录（通常是 `<工程名>.sim/sim_1/behav/xsim/`）:

```text
tv_in.txt
tv_gold_bits.txt
tv_gold_flags.txt
```

或者更简单：在 Vivado 里设置仿真运行目录为项目根目录：
- Settings → Simulation → Simulation → `simulation run directory` 选为项目根目录

### 综合

仿真全部通过后，跑综合：

1. 添加约束文件：`syn/constraints.xdc`（Add Sources → Add or create constraints）
2. Flow Navigator → **Run Synthesis**
3. 综合完成后，在 Tcl Console 里逐个跑报告：

```tcl
report_utilization      ;# LUT / FF / BRAM / DSP 用量
report_timing_summary   ;# WNS / TNS / Fmax
report_power            ;# 功耗估计
report_methodology      ;# DRC / 方法论检查
```

也可以在 Vivado Tcl Shell 里一键综合：

```sh
vivado -mode batch -source syn/vivado_synth.tcl
```

---

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

---

## 阈值说明

本码的列重实测为 3 和 4 混合，不是纯 4。因此翻转阈值使用自适应常数 `T=dv-1`：列重 4 的比特阈值为 3，列重 3 的比特阈值为 2。

---

## 常见调试问题

| 现象 | 最可能原因 | 排查方向 |
|------|-----------|---------|
| 全部帧第一轮就错 | 位序反了（文件左起是 bit[N-1] 还是 bit[0]） | 先用 8 比特玩具用例验证位序 |
| 部分帧迭代数差 1 | `>=` 写成了 `>` | 检查 conflict_flip.v 的阈值比较 |
| 比特全对但计数不对 | iter_count 语义差 1 | 检查 FSM 里 iter 的更新时机 |
| 恰好 50 轮收敛的帧 success 不一致 | max_iter 后没复查 syndrome | 检查 bf_decoder_top.v 的 `iter == MAX_ITER` 分支 |
| trace diff 有差异 | 某个模块的移位方向反了 | 看第一个分叉出现在第几轮第几位，定位到 syndrome_calc 或 conflict_flip |
