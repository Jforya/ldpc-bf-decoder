//=============================================================================
// conflict_flip.v — 冲突计数(conflict_counter) + 翻转判决(flip_decision)
//
// 原理: 比特块bj第q位连接的校验是 syndrome块bi的第(q-s)%Z位,
//   即贡献向量 = syndrome块循环左移s位: (sb<<s) | (sb>>(Z-s))
// 每比特冲突数 = 最多4个1bit贡献之和(3bit加法器),
// 翻转条件: cnt >= COLDEG[bj]-1 (列重自适应阈值, 常数比较)。
//=============================================================================
module conflict_flip #(
    parameter N = 2000,
    parameter M = 1600,
    parameter Z = 40
)(
    input  wire [M-1:0] synd,
    output wire [N-1:0] flip
);
    `include "qc_params.vh"

    genvar gbj, ge, gr;
    generate
        for (gbj = 0; gbj < NBLK; gbj = gbj + 1) begin : G_COL
            wire [MAX_CD*Z-1:0] c;
            for (ge = 0; ge < MAX_CD; ge = ge + 1) begin : G_TERM
                localparam [15:0]  E  = COLCONN[(gbj*MAX_CD+ge)*16 +: 16];
                localparam         V  = E[15];
                localparam integer BI = E[13:8];
                localparam integer S  = E[5:0];
                if (V) begin : G_ACT   // 循环左移S位
                    assign c[ge*Z +: Z] =
                        (synd[BI*Z +: Z] << S) | (synd[BI*Z +: Z] >> (Z - S));
                end else begin : G_PAD
                    assign c[ge*Z +: Z] = {Z{1'b0}};
                end
            end
            localparam [3:0]   DEG = COLDEG[gbj*4 +: 4];
            localparam integer TH  = DEG - 1;          // 阈值 T = dv - 1
            for (gr = 0; gr < Z; gr = gr + 1) begin : G_BIT
                wire [2:0] cnt = {2'b00, c[0*Z+gr]} + {2'b00, c[1*Z+gr]}
                               + {2'b00, c[2*Z+gr]} + {2'b00, c[3*Z+gr]};
                assign flip[gbj*Z + gr] = (cnt >= TH[2:0]);
            end
        end
    endgenerate
endmodule
