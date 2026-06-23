// conflict_flip.v
// 算法步骤(2)(3)(4): 由 syndrome 统计每个比特的冲突数,
// 并按自适应阈值 T=dv-1 组合产生同步翻转掩码。
// QC 等价关系: 从 syndrome 回到比特侧时使用相反方向的循环左移。

module conflict_flip #(
    parameter N = 2000,
    parameter M = 1600,
    parameter Z = 40
)(
    input  wire [M-1:0] synd,
    output wire [N-1:0] flip
);
    `include "qc_params.vh"

    genvar bj;
    generate
        for (bj = 0; bj < NBLK; bj = bj + 1) begin : gen_col_blk
            localparam [3:0] DEG = COLDEG[bj*4 +: 4];
            wire [ZP-1:0] contrib [0:MAX_CD-1];

            genvar e;
            for (e = 0; e < MAX_CD; e = e + 1) begin : gen_col_edge
                localparam [15:0] E = COLCONN[(bj*MAX_CD+e)*16 +: 16];
                localparam        V = E[15];
                localparam integer BI = E[13:8];
                localparam integer SH = E[5:0];

                wire [ZP-1:0] sb;
                assign sb = synd[BI*ZP +: ZP];

                if (V) begin : gen_valid
                    if (SH == 0) begin : gen_s0
                        assign contrib[e] = sb;
                    end else begin : gen_sn
                        assign contrib[e] = (sb << SH) | (sb >> (ZP-SH));
                    end
                end else begin : gen_invalid
                    assign contrib[e] = {ZP{1'b0}};
                end
            end

            genvar r;
            for (r = 0; r < ZP; r = r + 1) begin : gen_bit
                wire [2:0] cnt;
                assign cnt = {2'b00, contrib[0][r]} +
                             {2'b00, contrib[1][r]} +
                             {2'b00, contrib[2][r]} +
                             {2'b00, contrib[3][r]};

                assign flip[bj*ZP+r] = (cnt >= (DEG - 1'b1));
            end
        end
    endgenerate
endmodule
