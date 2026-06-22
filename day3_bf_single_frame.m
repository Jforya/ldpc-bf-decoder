% day3_bf_single_frame.m
% Day3: 单帧多比特 BF 译码器
%
% 目标:
%   bf_decode(y) -> success, iter_count, x_hat
%
% 固定语义:
%   1. 每轮先计算 syndrome = H * x' mod 2
%   2. syndrome 全 0: 成功退出
%   3. 每个比特统计 conflict = 它参与的校验方程中 syndrome=1 的个数
%   4. 阈值 T = 列重 - 1
%   5. conflict >= T 的比特同步翻转
%   6. 没有任何比特可翻: 提前失败
%   7. 最大迭代次数 max_iter = 50

clear; clc;

%% ---- 参数 ----
MB = 40;
NB = 50;
Z  = 40;
M  = MB * Z;   % 1600
N  = NB * Z;   % 2000
MAX_ITER = 50;

base_path = '/Users/none/Downloads/LDPC_比特翻转算法实现和译码器硬件设计/附件/qc_peg_40_50_invc6dplopt_shift_inv.txt';

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

col_weight = full(sum(H, 1));      % 每个比特参与几个校验方程
threshold  = col_weight - 1;       % 自适应阈值 T=dv-1

fprintf('H展开完成: %d x %d, 1的总数=%d\n', M, N, nnz(H));
fprintf('列重范围: %d ~ %d\n\n', min(col_weight), max(col_weight));

%% ---- 第2步: 四个 Day3 验收用例 ----
% 每个用例包含: 正确码字 c, 错误图样 e, 接收码字 y = mod(c + e, 2)
tests = {};

% 用例1: 全零码字 + 无错误，应当0轮成功
c0 = zeros(1, N);
e0 = zeros(1, N);
y0 = mod(c0 + e0, 2);
tests{end+1} = struct('name', '全零输入', 'y', y0, 'c', c0);

% 用例2: 全零码字 + 1个错误，一般应当1轮纠回
c1 = zeros(1, N);
e1 = zeros(1, N);
e1(123) = 1;
y1 = mod(c1 + e1, 2);
tests{end+1} = struct('name', '单比特错误', 'y', y1, 'c', c1);

% 用例3: 全零码字 + 5个错误，观察是否能在几轮内纠回
c5 = zeros(1, N);
e5 = zeros(1, N);
e5([123, 456, 789, 1200, 1777]) = 1;
y5 = mod(c5 + e5, 2);
tests{end+1} = struct('name', '5比特错误', 'y', y5, 'c', c5);

% 用例4: 全零码字 + 200个错误，通常应失败
rng(20260617);
c200 = zeros(1, N);
e200 = zeros(1, N);
pos200 = randperm(N, 200);
e200(pos200) = 1;
y200 = mod(c200 + e200, 2);
tests{end+1} = struct('name', '200比特错误', 'y', y200, 'c', c200);

for t = 1:numel(tests)
    fprintf('========== 用例%d: %s ==========\n', t, tests{t}.name);
    [success, iter_count, x_hat, syn_hist] = bf_decode_single(tests{t}.y, H, threshold, MAX_ITER, true);

    residual_errors = sum(x_hat ~= tests{t}.c);
    fprintf('结果: success=%d, iter_count=%d, residual_errors=%d\n', ...
        success, iter_count, residual_errors);
    fprintf('syndrome重量历史: ');
    fprintf('%d ', syn_hist);
    fprintf('\n\n');
end

%% ---- 单帧 BF 译码函数 ----
function [success, iter_count, x_hat, syn_hist] = bf_decode_single(y, H, threshold, max_iter, verbose)
    x_hat = y;
    syn_hist = zeros(1, max_iter + 1);  % 预分配，最多 max_iter 轮 + 1 次最终检查
    idx = 0;  % 已记录的轮数

    for it = 0 : max_iter-1
        % syndrome(m)=1 表示第 m 个校验方程不满足。
        syndrome = mod(H * x_hat.', 2).';
        syndrome_weight = sum(syndrome);
        idx = idx + 1;
        syn_hist(idx) = syndrome_weight;

        if verbose
            fprintf('第%2d轮开始: syndrome_weight=%d\n', it, syndrome_weight);
        end

        if syndrome_weight == 0
            success = true;
            iter_count = it;
            syn_hist = syn_hist(1:idx);  % 截断多余预分配
            return;
        end

        % conflict(n) = 第 n 个比特连接到的"不满足校验方程"数量。
        conflict = syndrome * H;

        % 同步翻转: 先一次性算出 flip_mask，再一起翻转。
        flip_mask = conflict >= threshold;
        flip_count = sum(flip_mask);

        if verbose
            fprintf('          本轮准备翻转比特数=%d\n', flip_count);
        end

        if flip_count == 0
            success = false;
            iter_count = it + 1;
            syn_hist = syn_hist(1:idx);
            return;
        end

        x_hat(flip_mask) = 1 - x_hat(flip_mask);
    end

    % 跑满 max_iter 后，再检查一次是否已经满足所有校验。
    syndrome = mod(H * x_hat.', 2).';
    idx = idx + 1;
    syn_hist(idx) = sum(syndrome);
    syn_hist = syn_hist(1:idx);
    success = (sum(syndrome) == 0);
    iter_count = max_iter;
end
