// bf_decoder_top.v
// 多比特 Bit-Flipping 顶层: IDLE/RUN FSM + x 寄存器。
// 每个 RUN 时钟周期组合完成 syndrome->conflict->flip, 然后同步翻转。

module bf_decoder_top #(
    parameter N = 2000,
    parameter K = 400,
    parameter Z = 40,
    parameter MAX_ITER = 50
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire [N-1:0] rx_bits,
    output reg done,
    output reg success,
    output reg [$clog2(MAX_ITER+1)-1:0] iter_count,
    output reg [N-1:0] decoded_bits
);
    localparam ITER_W = $clog2(MAX_ITER+1);
    localparam M = N - K;
    localparam [ITER_W-1:0] MAX_ITER_VAL = MAX_ITER;

    localparam ST_IDLE = 1'b0;
    localparam ST_RUN  = 1'b1;

    reg state;
    reg [ITER_W-1:0] iter;
    reg [N-1:0] x;

    wire [M-1:0] synd;
    wire [N-1:0] flip;
    wire syndrome_zero;
    wire any_flip;

    syndrome_calc #(
        .N(N),
        .M(M),
        .Z(Z)
    ) u_syndrome_calc (
        .x(x),
        .synd(synd)
    );

    conflict_flip #(
        .N(N),
        .M(M),
        .Z(Z)
    ) u_conflict_flip (
        .synd(synd),
        .flip(flip)
    );

    assign syndrome_zero = ~|synd;
    assign any_flip = |flip;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            state <= ST_IDLE;
            x <= {N{1'b0}};
            decoded_bits <= {N{1'b0}};
            done <= 1'b0;
            success <= 1'b0;
            iter <= {ITER_W{1'b0}};
            iter_count <= {ITER_W{1'b0}};
        end else begin
            done <= 1'b0;

            case(state)
                ST_IDLE: begin
                    if(start) begin
                        x <= rx_bits;
                        decoded_bits <= rx_bits;
                        success <= 1'b0;
                        iter <= {ITER_W{1'b0}};
                        iter_count <= {ITER_W{1'b0}};
                        state <= ST_RUN;
                    end
                end

                ST_RUN: begin
                    // 终止优先级必须与黄金模型一致:
                    // syndrome 全0成功 > 达到 MAX_ITER 失败 > 本轮无翻转提前失败。
                    if(syndrome_zero) begin
                        decoded_bits <= x;
                        success <= 1'b1;
                        iter_count <= iter;
                        done <= 1'b1;
                        state <= ST_IDLE;
                    end else if(iter == MAX_ITER_VAL) begin
                        decoded_bits <= x;
                        success <= 1'b0;
                        iter_count <= iter;
                        done <= 1'b1;
                        state <= ST_IDLE;
                    end else if(!any_flip) begin
                        decoded_bits <= x;
                        success <= 1'b0;
                        iter_count <= iter + {{(ITER_W-1){1'b0}},1'b1};
                        done <= 1'b1;
                        state <= ST_IDLE;
                    end else begin
                        x <= x ^ flip;
                        decoded_bits <= x ^ flip;
                        iter <= iter + {{(ITER_W-1){1'b0}},1'b1};
                    end
                end
            endcase
        end
    end
endmodule
