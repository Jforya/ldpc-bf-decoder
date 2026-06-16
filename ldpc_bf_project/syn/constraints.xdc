# constraints.xdc — 时序约束
# 全并行单周期迭代的关键路径较长(syndrome XOR树 -> 旋转布线 -> 3bit加 -> 比较
#  -> 2000bit XOR -> x寄存器), 起步目标定 100 MHz, 综合后按 WNS 调整:
#   WNS > 0  => 提高频率重综合, 摸出 Fmax
#   WNS < 0  => 降低频率, 或在 synd 后插一级流水(吞吐减半, 频率约x2)
create_clock -period 10.000 -name clk [get_ports clk]

# 顶层为超宽端口(2000bit), 仅做综合评估, 不绑定管脚; 实现时改用流式接口
set_property HD.CLK_SRC BUFGCTRL_X0Y0 [get_ports clk] -quiet
