// bf_tb.v
// 逐帧读取 C 黄金模型生成的测试向量, 比对 decoded_bits/success/iter_count,
// 并导出 RTL 每轮翻转后的轨迹 trace_rtl.txt 用于 diff。

`timescale 1ns/1ps

module bf_tb;
    localparam N = 2000;
    localparam K = 400;
    localparam Z = 40;
    localparam MAX_ITER = 50;
    localparam NF = 120;
    localparam ITER_W = $clog2(MAX_ITER+1);
    localparam [ITER_W-1:0] MAX_ITER_VAL = MAX_ITER;

    reg clk;
    reg rst_n;
    reg start;
    reg [N-1:0] rx_bits;
    wire done;
    wire success;
    wire [ITER_W-1:0] iter_count;
    wire [N-1:0] decoded_bits;

    reg [N-1:0] tv_in [0:NF-1];
    reg [N-1:0] tv_gold [0:NF-1];
    reg [7:0] tv_flags [0:NF-1];

    integer idx;
    integer fail_count;
    integer trace_fd;
    integer plusarg_ok;
    reg [8*256-1:0] tv_in_file;
    reg [8*256-1:0] tv_gold_bits_file;
    reg [8*256-1:0] tv_gold_flags_file;
    reg [8*256-1:0] trace_rtl_file;

    bf_decoder_top #(
        .N(N),
        .K(K),
        .Z(Z),
        .MAX_ITER(MAX_ITER)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rx_bits(rx_bits),
        .done(done),
        .success(success),
        .iter_count(iter_count),
        .decoded_bits(decoded_bits)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task write_bits;
        input integer fd;
        input [N-1:0] bits;
        integer b;
        begin
            for(b=N-1; b>=0; b=b-1) begin
                $fwrite(fd, "%0d", bits[b]);
            end
        end
    endtask

    always @(posedge clk) begin
        if(rst_n && dut.state == 1'b1 && !(~|dut.synd) && dut.iter != MAX_ITER_VAL && (|dut.flip)) begin
            $fwrite(trace_fd, "F%0d I%0d ", idx, dut.iter + 1'b1);
            write_bits(trace_fd, dut.x ^ dut.flip);
            $fwrite(trace_fd, "\n");
        end
    end

    initial begin
        tv_in_file = "tv_in.txt";
        tv_gold_bits_file = "tv_gold_bits.txt";
        tv_gold_flags_file = "tv_gold_flags.txt";
        trace_rtl_file = "trace_rtl.txt";

        plusarg_ok = $value$plusargs("TV_IN=%s", tv_in_file);
        plusarg_ok = $value$plusargs("TV_GOLD_BITS=%s", tv_gold_bits_file);
        plusarg_ok = $value$plusargs("TV_GOLD_FLAGS=%s", tv_gold_flags_file);
        plusarg_ok = $value$plusargs("TRACE_RTL=%s", trace_rtl_file);

        $readmemb(tv_in_file, tv_in);
        $readmemb(tv_gold_bits_file, tv_gold);
        $readmemb(tv_gold_flags_file, tv_flags);

        trace_fd = $fopen(trace_rtl_file, "w");
        if(trace_fd == 0) begin
            $display("FAIL: cannot open trace file %0s", trace_rtl_file);
            $finish;
        end

        rst_n = 1'b0;
        start = 1'b0;
        rx_bits = {N{1'b0}};
        fail_count = 0;
        idx = 0;

        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        for(idx=0; idx<NF; idx=idx+1) begin
            rx_bits = tv_in[idx];
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            #1;
            while(!done) begin
                @(posedge clk);
                #1;
            end

            if(decoded_bits !== tv_gold[idx] ||
               success !== tv_flags[idx][7] ||
               iter_count !== tv_flags[idx][ITER_W-1:0]) begin
                fail_count = fail_count + 1;
                $display("Frame %0d mismatch: bits_match=%0d success rtl/gold=%0d/%0d iter rtl/gold=%0d/%0d",
                         idx,
                         (decoded_bits === tv_gold[idx]),
                         success, tv_flags[idx][7],
                         iter_count, tv_flags[idx][ITER_W-1:0]);
            end

            @(posedge clk);
        end

        $fclose(trace_fd);

        if(fail_count == 0) begin
            $display("PASS: all %0d frames match", NF);
        end else begin
            $display("FAIL: %0d frames mismatched", fail_count);
        end

        $finish;
    end
endmodule
