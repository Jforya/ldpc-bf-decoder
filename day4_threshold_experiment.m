% day4_threshold_experiment.m
% Day4: BSC仿真框架 + 阈值策略对比实验
%
% 目标:
%   1. 搭建 BSC 随机噪声仿真循环
%   2. 比较固定阈值 T=3 与自适应阈值 T=dv-1
%   3. 在 RBER = 0.02, 0.03, 0.04 各跑 300 帧
%
% 输出:
%   day4_threshold_results.csv

clear; clc;

%% ---- 参数 ----
MB = 40;
NB = 50;
Z  = 40;
M  = MB * Z;   % 1600
N  = NB * Z;   % 2000
MAX_ITER = 50;
FRAMES_PER_POINT = 300;

rber_points = [0.02, 0.03, 0.04];
base_path = '/Users/none/Downloads/LDPC_比特翻转算法实现和译码器硬件设计/附件/qc_peg_40_50_invc6dplopt_shift_inv.txt';

% 固定随机种子，保证每次运行结果可复现。
rng(20260617);

%% ---- 第1步: 展开 H ----
B = load(base_path);
H = sparse(M, N);

for bi = 0 : MB-1
    for bj = 0 : NB-1
        s = B(bi+1, bj+1);
        if s < 0
            continue;
        end

        for r = 0 : Z-1
            row = bi*Z + r + 1;
            col = bj*Z + mod(r+s, Z) + 1;
            H(row, col) = 1;
        end
    end
end

col_weight = full(sum(H, 1));
threshold_fixed = 3 * ones(1, N);
threshold_adapt = col_weight - 1;

fprintf('H展开完成: %d x %d, 1的总数=%d\n', M, N, nnz(H));
fprintf('列重范围: %d ~ %d\n\n', min(col_weight), max(col_weight));

%% ---- 第2步: 对比实验 ----
result_rows = [];

fprintf('RBER    策略          帧数   错误帧   FER       平均迭代\n');
fprintf('----------------------------------------------------------\n');

for p = 1:numel(rber_points)
    rber = rber_points(p);

    fixed_frame_errors = 0;
    fixed_iter_sum = 0;
    adapt_frame_errors = 0;
    adapt_iter_sum = 0;

    for f = 1:FRAMES_PER_POINT
        % BSC信道: 发送全零码字，每个比特以概率 rber 独立翻转。
        y = double(rand(1, N) < rber);

        % 为了公平，固定阈值和自适应阈值使用同一帧噪声 y。
        [ok_fixed, it_fixed, x_fixed] = bf_decode_threshold(y, H, threshold_fixed, MAX_ITER);
        [ok_adapt, it_adapt, x_adapt] = bf_decode_threshold(y, H, threshold_adapt, MAX_ITER);

        % 失败判定:
        %   1. 译码器自己报告失败
        %   2. 虽然 syndrome 全0，但结果不是全零码字，说明译成了错误码字
        fixed_fail = (~ok_fixed) || any(x_fixed ~= 0);
        adapt_fail = (~ok_adapt) || any(x_adapt ~= 0);

        fixed_frame_errors = fixed_frame_errors + fixed_fail;
        adapt_frame_errors = adapt_frame_errors + adapt_fail;
        fixed_iter_sum = fixed_iter_sum + it_fixed;
        adapt_iter_sum = adapt_iter_sum + it_adapt;
    end

    fixed_fer = fixed_frame_errors / FRAMES_PER_POINT;
    adapt_fer = adapt_frame_errors / FRAMES_PER_POINT;
    fixed_avg_iter = fixed_iter_sum / FRAMES_PER_POINT;
    adapt_avg_iter = adapt_iter_sum / FRAMES_PER_POINT;

    fprintf('%.2f    %-12s %4d   %5d   %.4f    %.2f\n', ...
        rber, 'fixed_T3', FRAMES_PER_POINT, fixed_frame_errors, fixed_fer, fixed_avg_iter);
    fprintf('%.2f    %-12s %4d   %5d   %.4f    %.2f\n', ...
        rber, 'adaptive', FRAMES_PER_POINT, adapt_frame_errors, adapt_fer, adapt_avg_iter);

    result_rows = [result_rows; ...
        rber, 1, FRAMES_PER_POINT, fixed_frame_errors, fixed_fer, fixed_avg_iter; ...
        rber, 2, FRAMES_PER_POINT, adapt_frame_errors, adapt_fer, adapt_avg_iter]; %#ok<AGROW>
end

%% ---- 第3步: 保存CSV ----
out = array2table(result_rows, ...
    'VariableNames', {'rber', 'strategy_id', 'frames', 'frame_errors', 'fer', 'avg_iter'});

strategy = strings(height(out), 1);
strategy(out.strategy_id == 1) = "fixed_T3";
strategy(out.strategy_id == 2) = "adaptive_dv_minus_1";
out.strategy = strategy;
out = movevars(out, 'strategy', 'After', 'rber');
out.strategy_id = [];

writetable(out, 'day4_threshold_results.csv');

fprintf('\n已保存: day4_threshold_results.csv\n');

%% ---- 单帧BF译码函数：阈值作为参数传入 ----
function [success, iter_count, x_hat] = bf_decode_threshold(y, H, threshold, max_iter)
    x_hat = y;
    success = false;
    iter_count = 0;

    for it = 0 : max_iter-1
        syndrome = mod(H * x_hat.', 2).';
        syndrome_weight = sum(syndrome);

        if syndrome_weight == 0
            success = true;
            iter_count = it;
            return;
        end

        conflict = syndrome * H;
        flip_mask = conflict >= threshold;
        flip_count = sum(flip_mask);

        if flip_count == 0
            success = false;
            iter_count = it + 1;
            return;
        end

        x_hat(flip_mask) = 1 - x_hat(flip_mask);
    end

    syndrome = mod(H * x_hat.', 2).';
    success = (sum(syndrome) == 0);
    iter_count = max_iter;
end
