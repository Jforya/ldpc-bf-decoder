//=============================================================================
// bf_tb.v — RTL与软件黄金模型一致性验证
//
// 输入文件(由 bf_sim.c vectors模式生成):
//   tv_in.txt         噪声帧 (每行2000bit, 左=bit[1999])
//   tv_gold_bits.txt  黄金译码输出
//   tv_gold_flags.txt 每行8bit {success, iter_count[6:0]}
// 输出:
//   trace_rtl.txt     RTL每轮翻转后的x快照, 与 trace_gold.txt diff 应为空
// 判定: 每帧比对 decoded_bits / success / iter_count 三项全对才算PASS
//=============================================================================
`timescale 1ns/1ps

module bf_tb;
    localparam N = 2000, K = 400, Z = 40, MAX_ITER = 50;
    localparam NF = 120;                       // 帧数
    localparam IW = $clog2(MAX_ITER+1);

    reg clk = 0, rst_n = 0, start = 0;
    reg  [N-1:0] rx_bits;
    wire done, success;
    wire [IW-1:0] iter_count;
    wire [N-1:0] decoded_bits;

    bf_decoder_top #(.N(N), .K(K), .Z(Z), .MAX_ITER(MAX_ITER)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .rx_bits(rx_bits),
        .done(done), .success(success), .iter_count(iter_count),
        .decoded_bits(decoded_bits)
    );

    always #5 clk = ~clk;                      // 100 MHz

    reg [N-1:0] tv_in   [0:NF-1];
    reg [N-1:0] tv_gold [0:NF-1];
    reg [7:0]   tv_flag [0:NF-1];

    integer f, errors, ft, cyc;
    integer cur_frame;

    // 逐轮轨迹: 在RUN态且本周期将执行翻转时, 记录翻转后的x (轮号=iter+1)
    always @(negedge clk) begin
        if (dut.state == 1'b1 && !dut.synd_zero
            && dut.iter != MAX_ITER[IW-1:0] && dut.flip_any)
            $fwrite(ft, "F%0d I%0d %b\n", cur_frame, dut.iter + 1, dut.x ^ dut.flip);
    end

    task run_frame(input integer idx);
        begin
            cur_frame = idx;
            rx_bits = tv_in[idx];
            @(negedge clk); start = 1;
            @(negedge clk); start = 0;
            cyc = 0;
            while (!done && cyc < MAX_ITER + 10) begin @(negedge clk); cyc = cyc + 1; end
            if (!done) begin
                $display("FRAME %0d: TIMEOUT", idx); errors = errors + 1;
            end else if (decoded_bits !== tv_gold[idx]
                      || success      !== tv_flag[idx][7]
                      || iter_count   !== tv_flag[idx][IW-1:0]) begin
                $display("FRAME %0d: MISMATCH (rtl s=%b it=%0d / gold s=%b it=%0d, bits %s)",
                         idx, success, iter_count, tv_flag[idx][7], tv_flag[idx][6:0],
                         (decoded_bits === tv_gold[idx]) ? "match" : "DIFFER");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $readmemb("tv_in.txt",         tv_in);
        $readmemb("tv_gold_bits.txt",  tv_gold);
        $readmemb("tv_gold_flags.txt", tv_flag);
        ft = $fopen("trace_rtl.txt", "w");
        errors = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;
        for (f = 0; f < NF; f = f + 1) run_frame(f);
        $fclose(ft);
        if (errors == 0)
            $display("PASS: all %0d frames match golden model (bits + success + iter_count)", NF);
        else
            $display("FAIL: %0d / %0d frames mismatched", errors, NF);
        $finish;
    end
endmodule
