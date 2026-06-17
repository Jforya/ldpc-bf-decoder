% expand_H.m — 读取QC-LDPC基矩阵，展开成完整H矩阵，并验证
% 项目: LDPC比特翻转译码器  Day2
% 随机种子: 无（今天只做矩阵展开，不涉及随机）

%% ---- 参数 ----
MB = 40;   % 基矩阵行数
NB = 50;   % 基矩阵列数
Z  = 40;   % 每个块的大小（子矩阵尺寸）
M  = MB * Z;   % H的行数 = 1600（校验方程数）
N  = NB * Z;   % H的列数 = 2000（码长）

%% ---- 第1步：读基矩阵 ----
fpath = '/Users/none/Downloads/LDPC_比特翻转算法实现和译码器硬件设计/附件/qc_peg_40_50_invc6dplopt_shift_inv.txt';
B = load(fpath);   % MATLAB的load可以直接读纯数字文本，得到40×50矩阵

fprintf('基矩阵读入成功，尺寸: %d × %d\n', size(B,1), size(B,2));

%% ---- 第2步：展开成H ----
H = zeros(M, N, 'uint8');   % 用uint8省内存（元素只有0和1）

for bi = 0 : MB-1          % 基矩阵块行号，0-based
    for bj = 0 : NB-1      % 基矩阵块列号，0-based
        s = B(bi+1, bj+1); % MATLAB下标从1开始，所以+1
        if s < 0
            continue        % -1表示全零块，跳过
        end
        for r = 0 : Z-1    % 块内行号，0-based
            row = bi*Z + r + 1;              % H中的行（转成1-based）
            col = bj*Z + mod(r+s, Z) + 1;   % H中的列：循环右移s位
            H(row, col) = 1;
        end
    end
end

fprintf('H矩阵展开完成，尺寸: %d × %d\n', M, N);

%% ---- 第3步：验证 ----
total_ones = sum(H(:));
col_weights = sum(H, 1);   % 每列之和（列重）= 该比特参与几个方程
row_weights = sum(H, 2);   % 每行之和（行重）= 该方程包含几个比特

fprintf('\n========== 验证结果 ==========\n');
fprintf('H中1的总数:        %d  （期望: 7880）\n', total_ones);
fprintf('列重（列之和）最小: %d  最大: %d  （期望: 3和4混合）\n', min(col_weights), max(col_weights));
fprintf('行重（行之和）最小: %d  最大: %d  （期望: 4到6）\n',    min(row_weights), max(row_weights));
fprintf('列重=3的列数: %d\n', sum(col_weights == 3));
fprintf('列重=4的列数: %d\n', sum(col_weights == 4));
fprintf('==============================\n');

%% ---- 第4步：画稀疏图 ----
figure('Position', [100 100 900 600]);
spy(H);
title('H矩阵稀疏结构（黑点=1）', 'FontSize', 14);
xlabel('码字比特编号（列）');
ylabel('校验方程编号（行）');
fprintf('\n稀疏图已显示。\n');