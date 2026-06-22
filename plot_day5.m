% plot_day5.m
% Day5: 读取 day5_fer_curve.csv 并绘制 RBER-FER / RBER-UBER / 平均迭代曲线

clear; clc;

data = readtable('day5_fer_curve.csv');

fprintf('读取到 %d 个RBER点。\n', height(data));
disp(data);

%% RBER-FER
figure('Position', [100 100 760 520]);
semilogy(data.rber, data.fer, '-o', 'LineWidth', 2);
grid on;
xlabel('Raw bit error rate (RBER)');
ylabel('Frame error rate (FER)');
title('QC-LDPC BF decoder: RBER-FER, MAX\_ITER=50, T=dv-1');

for i = 1:height(data)
    text(data.rber(i), data.fer(i), sprintf('  %d frames', data.frames(i)), ...
        'FontSize', 8, 'VerticalAlignment', 'bottom');
end

saveas(gcf, 'day5_rber_fer.png');

%% RBER-UBER
figure('Position', [130 130 760 520]);
semilogy(data.rber, data.uber, '-o', 'LineWidth', 2);
grid on;
xlabel('Raw bit error rate (RBER)');
ylabel('Uncorrectable bit error rate (UBER)');
title('QC-LDPC BF decoder: RBER-UBER, MAX\_ITER=50, T=dv-1');

for i = 1:height(data)
    text(data.rber(i), data.uber(i), sprintf('  %d frames', data.frames(i)), ...
        'FontSize', 8, 'VerticalAlignment', 'bottom');
end

saveas(gcf, 'day5_rber_uber.png');

%% Average iterations
figure('Position', [160 160 760 520]);
plot(data.rber, data.avg_iter, '-o', 'LineWidth', 2);
grid on;
xlabel('Raw bit error rate (RBER)');
ylabel('Average iterations');
title('QC-LDPC BF decoder: average iterations, MAX\_ITER=50, T=dv-1');
saveas(gcf, 'day5_avg_iter.png');

fprintf('已生成图片:\n');
fprintf('  day5_rber_fer.png\n');
fprintf('  day5_rber_uber.png\n');
fprintf('  day5_avg_iter.png\n');
