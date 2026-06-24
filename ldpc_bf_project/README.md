# QC-LDPC Multi-bit BF 译码器项目

---

## 方式一：命令行快速仿真 (iverilog, 推荐用于快速验证)

### 1. 编译 C 程序，生成测试向量

```bash
gcc -O2 -o bf_sim bf_sim.c
./bf_sim vectors base.txt 120
```

这一步做了什么：
- `bf_sim.c` 是 C 黄金模型（软件参考译码器），包含了和 RTL 完全一致的译码算法
- `vectors` 模式生成 120 帧测试数据，包含无错帧、单错帧、多错帧、BSC 随机错帧四种混合场景
- 输出文件：
  - `tv_in.txt` — 每行 2000 个 '0'/'1'，是加噪后的接收序列，作为 RTL 的输入激励
  - `tv_gold_bits.txt` — 每行 2000 个 '0'/'1'，C 模型译码结果，作为"标准答案"
  - `tv_gold_flags.txt` — 每行 8 位二进制，`{success, iter_count[6:0]}`，记录每帧是否成功 + 用了多少轮
  - `trace_gold.txt` — 每轮翻转后的码字快照，格式 `F<帧号> I<轮号> <2000bit>`，用于逐轮逐比特对比

### 2. 生成 RTL 参数文件

```bash
python gen_qc_params.py base.txt
mv qc_params.vh rtl/
```

这一步做了什么：
- 基矩阵 `base.txt`（40×50）里的元素是循环移位值 s，RTL 里需要知道每个校验方程连接了哪些比特
- `gen_qc_params.py` 把基矩阵预编译成 Verilog 可直接使用的常数表，写入 `qc_params.vh`：
  - `ROWCONN` — 行连接表，syndrome_calc 用（1600 行，每行最多 6 个连接块）
  - `COLCONN` — 列连接表，conflict_flip 用（2000 列，每列最多 4 个连接块）
  - `COLDEG` — 每列列重（3 或 4），推导出自适应阈值 T = dv-1
- 因为 QC 结构里移位量都是常数，综合后这些"旋转"变成纯布线，不消耗逻辑

### 3. 用 iverilog 编译并仿真

```bash
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

```bash
diff trace_gold.txt trace_rtl.txt
```

这一步做了什么：
- C 模型（`trace_gold.txt`）和 RTL 仿真（`trace_rtl.txt`）各自记录了每轮翻转后的码字
- `diff` 逐行比较两个文件，如果**输出为空**，说明 504 个迭代快照（120 帧 × 平均 4.2 轮）逐位完全一致
- 这是任务书要求的最高级别验证——不是只看最终结果，而是每一轮中间状态都对
- 如果有差异，看第一个分叉出现在第几帧第几轮第几位，直接定位到对应模块

---

## 方式二：Vivado GUI 仿真 + 综合

### 前置：先生成测试向量（同方式一的步骤 1-2）

### 1. 创建工程
- Create Project → RTL Project，器件选 **xc7a200tfbg676-2**（Artix-7）
- 添加 Design Sources: `rtl/bf_decoder_top.v`, `rtl/syndrome_calc.v`, `rtl/conflict_flip.v`
- 添加 Simulation Sources: `rtl/bf_tb.v`，右键 **Set as Top**
- 添加 Constraints: `syn/constraints.xdc`

### 2. 配置 include 路径
- Settings → Simulation → Verilog options
- Include Files Search Paths: 添加 `rtl/` 目录

### 3. 配置仿真运行目录
- Settings → Simulation → Simulation
- Simulation run directory: 选 `ldpc_bf_project/`（使 `$readmemb` 能在当前目录找到 `tv_*.txt`）

### 4. 行为仿真
- Run Simulation → Run Behavioral Simulation
- Tcl Console 输入 `run all`
- 看到 `PASS: all 120 frames match golden model` 即通过

### 5. 逐轮轨迹比对 (Git Bash)
```bash
diff trace_gold.txt trace_rtl.txt        # 输出为空 = 完全一致
```

### 6. 综合
- Run Synthesis
- Tcl Console 跑报告：
```tcl
report_utilization      ;# LUT / FF / BRAM / DSP 用量
report_timing_summary   ;# WNS / TNS / Fmax
report_power            ;# 功耗估计
report_methodology      ;# DRC / 方法论检查
```

---

## 备选：Vivado 命令行一键综合
```bash
vivado -mode batch -source syn/vivado_synth.tcl
```

---

## 各模块功能速查

| 文件 | 功能 | 核心原理 |
|------|------|---------|
| `bf_sim.c` | C 黄金模型 | 稀疏连接表 + 同步翻转 + 自适应阈值 T=dv-1 |
| `syndrome_calc.v` | 校验子计算 s=Hx | QC 循环右移 → XOR 树（行重≤6，纯布线） |
| `conflict_flip.v` | 冲突计数 + 翻转 | QC 循环左移 → 3bit 加法 → 阈值比较 |
| `bf_decoder_top.v` | 顶层 FSM | IDLE→RUN，三出口：全零成功/翻满失败/无翻转失败 |
| `bf_tb.v` | 一致性验证 | `$readmemb` 读入 → 逐帧驱动 → 三项比对 + 逐轮快照 |
| `qc_params.vh` | 连接常数表 | 由 `gen_qc_params.py` 从基矩阵自动生成 |
| `gen_qc_params.py` | 参数生成脚本 | 将基矩阵编译为 RTL 可用的 ROM 连接表 |
| `constraints.xdc` | 时序约束 | 100MHz 时钟目标 |

## 译码算法语义（RTL 和 C 模型一致）

1. x = 接收硬判决序列
2. 计算 s = H × x (mod 2)，若 s 全 0 → **成功**
3. 对每比特 j，统计它参与的校验中不满足的个数 conflict[j]
4. **同步翻转**所有 conflict[j] ≥ T[j] 的比特，其中 T[j] = 列重 dv[j] - 1
5. 若本轮无比特翻转 → **提前失败**
6. 重复 2-5，最多 MAX_ITER=50 轮

## 已验证结果
120/120 帧三项输出（decoded_bits / success / iter_count）全对，
504 个迭代快照逐位 diff 为空；
yosys 综合: 10701 LUT6 / 4015 FF / 0 BRAM / 0 DSP，最长路径 9 级 LUT。
