//=============================================================================
// syndrome_calc.v — 计算 s = H * x (mod 2), 利用QC结构
//
// 原理: H的块(bi,bj)是单位阵循环右移s位, 即 H[r][(r+s)%Z]=1。
//   syndrome块bi的第r位 = XOR_{bj} x块bj的第(r+s)%Z位
//   => 每个参与块的贡献 = x块循环右移s位:  (xb>>s) | (xb<<(Z-s))
// s为生成时常数 -> 综合后是纯布线 + 浅XOR树(行重<=6)。
// 连接表ROWCONN由 gen_qc_params.py 从基矩阵生成 (即 h_matrix_rom/qc_addr_gen)。
//=============================================================================
module syndrome_calc #(
    parameter N = 2000,
    parameter M = 1600,
    parameter Z = 40
)(
    input  wire [N-1:0] x,
    output wire [M-1:0] synd
);
    `include "qc_params.vh"

    genvar gbi, ge;
    generate
        for (gbi = 0; gbi < MBLK; gbi = gbi + 1) begin : G_ROW
            wire [MAX_RD*Z-1:0] term;
            for (ge = 0; ge < MAX_RD; ge = ge + 1) begin : G_TERM
                localparam [15:0]  E  = ROWCONN[(gbi*MAX_RD+ge)*16 +: 16];
                localparam         V  = E[15];
                localparam integer BJ = E[13:8];
                localparam integer S  = E[5:0];
                if (V) begin : G_ACT   // 循环右移S位 (S=0时 <<Z 结果为0, 表达式仍正确)
                    assign term[ge*Z +: Z] =
                        (x[BJ*Z +: Z] >> S) | (x[BJ*Z +: Z] << (Z - S));
                end else begin : G_PAD
                    assign term[ge*Z +: Z] = {Z{1'b0}};
                end
            end
            assign synd[gbi*Z +: Z] = term[0*Z +: Z] ^ term[1*Z +: Z]
                                    ^ term[2*Z +: Z] ^ term[3*Z +: Z]
                                    ^ term[4*Z +: Z] ^ term[5*Z +: Z];
        end
    endgenerate
endmodule
