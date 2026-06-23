// syndrome_calc.v
// 算法步骤(1): 组合计算 syndrome = H*x (mod 2)。
// QC 等价关系: 每个非零子块是单位阵循环右移 s 位,
// 因而 syndrome 块等于相关 x 块循环右移 s 位后按位异或。

module syndrome_calc #(
    parameter N = 2000,
    parameter M = 1600,
    parameter Z = 40
)(
    input  wire [N-1:0] x,
    output wire [M-1:0] synd
);
    `include "qc_params.vh"

    genvar bi;
    generate
        for (bi = 0; bi < MBLK; bi = bi + 1) begin : gen_row_blk
            wire [ZP-1:0] acc [0:MAX_RD];
            assign acc[0] = {ZP{1'b0}};

            genvar e;
            for (e = 0; e < MAX_RD; e = e + 1) begin : gen_row_edge
                localparam [15:0] E = ROWCONN[(bi*MAX_RD+e)*16 +: 16];
                localparam        V = E[15];
                localparam integer BJ = E[13:8];
                localparam integer SH = E[5:0];

                wire [ZP-1:0] xb;
                wire [ZP-1:0] rot;

                assign xb = x[BJ*ZP +: ZP];
                if (V) begin : gen_valid
                    if (SH == 0) begin : gen_s0
                        assign rot = xb;
                    end else begin : gen_sn
                        assign rot = (xb >> SH) | (xb << (ZP-SH));
                    end
                    assign acc[e+1] = acc[e] ^ rot;
                end else begin : gen_invalid
                    assign rot = {ZP{1'b0}};
                    assign acc[e+1] = acc[e];
                end
            end

            assign synd[bi*ZP +: ZP] = acc[MAX_RD];
        end
    endgenerate
endmodule
