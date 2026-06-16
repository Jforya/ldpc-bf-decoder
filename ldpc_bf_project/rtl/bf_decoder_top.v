//=============================================================================
// bf_decoder_top.v — QC-LDPC 多比特翻转译码器 顶层
//
// 码: (2000,400), Z=40, 基矩阵40x50, 列重3/4
// 算法语义与软件黄金模型 bf_sim.c 严格一致:
//   每周期完成一轮: syndrome -> 冲突计数 -> 同步翻转所有 cnt>=dv-1 的比特
//   终止: syndrome全0(成功) / 本轮无比特翻转(失败) / 翻满MAX_ITER轮后复查
//
// 注: 任务书建议参数含THRESH; 本设计采用列重自适应阈值 T=dv-1(性能更优,
//     见报告4.2节实验), 阈值由 qc_params.vh 的 COLDEG 推导, 故无THRESH参数。
//=============================================================================
`timescale 1ns/1ps

module bf_decoder_top #(
    parameter N        = 2000,
    parameter K        = 400,
    parameter Z        = 40,
    parameter MAX_ITER = 50
)(
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              start,
    input  wire [N-1:0]                      rx_bits,
    output reg                               done,
    output reg                               success,
    output reg  [$clog2(MAX_ITER+1)-1:0]     iter_count,
    output reg  [N-1:0]                      decoded_bits
);
    localparam M = N - K;                    // 1600 校验方程
    localparam IW = $clog2(MAX_ITER+1);

    // 当前码字估计 + 迭代计数
    reg  [N-1:0]  x;
    reg  [IW-1:0] iter;
    reg           state;                     // 0=IDLE/DONE, 1=RUN
    localparam S_IDLE = 1'b0, S_RUN = 1'b1;

    // 组合数据通路: 一轮迭代
    wire [M-1:0] synd;
    wire [N-1:0] flip;
    syndrome_calc  #(.N(N), .M(M), .Z(Z)) u_synd (.x(x),    .synd(synd));
    conflict_flip  #(.N(N), .M(M), .Z(Z)) u_flip (.synd(synd), .flip(flip));

    wire synd_zero = ~(|synd);
    wire flip_any  = |flip;

    // control_fsm: CHECK/COUNT/FLIP在本设计中于同一周期组合完成,
    // 故FSM仅需 IDLE <-> RUN 两态
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; done <= 1'b0; success <= 1'b0;
            iter <= {IW{1'b0}}; iter_count <= {IW{1'b0}};
            x <= {N{1'b0}}; decoded_bits <= {N{1'b0}};
        end else begin
            case (state)
            S_IDLE: if (start) begin
                x     <= rx_bits;            // 输入锁存 (bit_update_mem)
                iter  <= {IW{1'b0}};
                done  <= 1'b0;
                state <= S_RUN;
            end
            S_RUN: begin
                if (synd_zero) begin                  // 所有校验满足 -> 成功
                    success <= 1'b1; iter_count <= iter;
                    decoded_bits <= x; done <= 1'b1; state <= S_IDLE;
                end else if (iter == MAX_ITER[IW-1:0]) begin // 翻满仍不满足 -> 失败
                    success <= 1'b0; iter_count <= iter;
                    decoded_bits <= x; done <= 1'b1; state <= S_IDLE;
                end else if (!flip_any) begin         // 无比特可翻 -> 提前失败
                    success <= 1'b0; iter_count <= iter + 1'b1;
                    decoded_bits <= x; done <= 1'b1; state <= S_IDLE;
                end else begin                        // 同步翻转, 进入下一轮
                    x    <= x ^ flip;
                    iter <= iter + 1'b1;
                end
            end
            endcase
        end
    end
endmodule
