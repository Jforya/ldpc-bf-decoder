%打孔列在后

%生成vivado代码所需ROM的文件 与掩码后的H基础矩阵（可逆的）
% 1.H1_value.coe  列重个序号值+H1的值   × (K_BASE)
% 2.H2_value.coe  H2的值  × (行数-pre个数)
% 3.H2_inv_value.coe  列重个扩展后的H2_inv的每个子矩阵的第一列数据  ×（pre个数）

% 0.invable_H_DATA.txt 可逆的H矩阵
ROWNUM = 11;
INFNUM = 130;
COLNUM = ROWNUM + INFNUM;
FILE_NAME = strcat('qc_peg_',num2str(ROWNUM),'_' , num2str(COLNUM) ,'_invc6dplopt_shift_inv.txt');
FILE_FOLDER = './base_matrix/4k/';



data_path = strcat(FILE_FOLDER,FILE_NAME);  
%'./base_matrix/4k/qc_peg_16_145_invc6dplopt_shift_inv.txt';
T = readtable(data_path);
H_data = table2array(T);    %H

N_BASE = size(H_data,2) ;   %基础矩阵列数
M_BASE = size(H_data,1) ;   %基础矩阵行数
K_BASE = N_BASE-M_BASE;   %信息位数
q = 257 ;
BLOCK_SIZE = q-1;   %子矩阵大小 256
H1_NUM_WIDTH = 5;
BLK_SIZE_WIDTH = 9;%256
COL_WEIGHT = 4;
P_PRE_CAL_NUM = 3;  %需要预先求出的P解数量
PCM_MASK = 256;


H2_data_origin = H_data(:,K_BASE+1:N_BASE);
H2_mat_origin_exp = func_gen_h(H2_data_origin,q-1);				% H2 扩展为元素为0/1的完整矩阵
% % 
% [flag_origin ,~] = func_inv2 (H2_mat_origin_exp) ;  % H2逆
rank_H_mat_2 = gfrank(H2_mat_origin_exp);
if(rank_H_mat_2 == (q-1)*M_BASE)
    disp('keni!\n');
else
    disp('111!\n');
end

% if(flag_origin == 1)
%     disp('可逆!\n');
% end

[H_data, valid_0, inv_H2] = func_full_rank_check(H_data, N_BASE, M_BASE, q, 4);   %保证基础矩阵H2可逆
if(valid_0 == 1)    %如果valid_0=0，则说明不可逆
    disp('irreversible!\n');
end

% fid_H = fopen('./base_matrix/invable_256_H_DATA.txt','w');
% for i = 1:M_BASE
%     for j =1 :N_BASE
%         fprintf(fid_H,'%s\t',num2str(H_data(i,j)));
%     end
%     fprintf(fid_H,'\n'); 
% end
% fclose(fid_H);



H1_data = H_data(:,1:K_BASE);
H2_data = H_data(:,K_BASE+1:N_BASE);

H1_mat_exp = func_gen_h(H1_data,q-1);				% H1 扩展为元素为0/1的完整矩阵
H2_mat_exp = func_gen_h(H2_data,q-1);				% H2 扩展为元素为0/1的完整矩阵



%-------------------------H1_value.coe------------------------
H1_coe_path = strcat('./gen_coe/4k/256_2_H1_value_',num2str(ROWNUM),'.coe') 
%'./gen_coe/4k/256_2_H1_value_16.coe' ;
H1_ps = fopen(H1_coe_path,'w');
fprintf(H1_ps,'memory_initialization_radix = 2;\n');
fprintf(H1_ps,'memory_initialization_vector =\n');
%该程序仅使用于阶梯形构造的H1 且不带hold 且列重固定 没有掩膜的
for j = 1 : K_BASE
    k=1;
    %for i = 1 : M_BASE
    %    if (H1_data(i,j) ~= -1)
    %        H1_idx(k) = i;
    %        H1_shift_data(k) = H1_data(i,j);
    %        if(k>COL_WEIGHT)
    %            disp('error');
    %        end
    %        k = k+1;
    %    end
    %end
    %阶梯型第一个非0元素位置 
    start = mod(j-1,M_BASE)+1;
    for k = 1 : COL_WEIGHT
        if (H1_data(start,j) == -1)
            H1_shift_data(k) = PCM_MASK;
        else
            H1_shift_data(k) = H1_data(start,j);
        end
        start = mod(start,M_BASE)+1;
    end
    %阶梯构造的H1 前面不需要 存位置信息， 改为多存一个Hold的信息
    %Hold信息也不存了，因为一直在移位

    %for k = 1 : COL_WEIGHT
    %    fprintf(H1_ps,'%s',num2str(dec2bin(H1_idx(k),H1_NUM_WIDTH)));
    %end
    for k = 1 : COL_WEIGHT
        fprintf(H1_ps,'%s',num2str(dec2bin(H1_shift_data(k),BLK_SIZE_WIDTH)));
    end
    fprintf(H1_ps,'\n'); 
end
fclose(H1_ps);

%-------------------------H2_value.coe------------------------
H2_coe_path = strcat('./gen_coe/4k/256_2_H2_value_',num2str(ROWNUM),'.coe')
%'./gen_coe/4k/256_2_H2_value_16.coe' ;
H2_ps = fopen(H2_coe_path,'w');
fprintf(H2_ps,'memory_initialization_radix = 2;\n');
fprintf(H2_ps,'memory_initialization_vector =\n');

OFFSET_1 = 0;% 初始值相对于第一列CNU未被掩掉的块编号为1-5的位移值，向下为正  
OFFSET_2 = OFFSET_1 - COL_WEIGHT + 1 ;% 初始值相对于第一行CNU未被掩掉的块编号为1-5的位移值，向右为正  H2的起始数据的列偏移值

for i = 1 : M_BASE - P_PRE_CAL_NUM
    %H2第一列数据
    if(i <= COL_WEIGHT)
        H2_shift_data(i,5) = PCM_MASK;
    else 
        if (H_data(M_BASE-i+1,N_BASE) == -1)
            H2_shift_data(i,5) = PCM_MASK;
        else
            H2_shift_data(i,5) = H_data(M_BASE-i+1,N_BASE);
        end
    end


    %start_position
    if (mod(COL_WEIGHT-i,M_BASE)==0)
		start_position = M_BASE; %start_position为H2中非零元素的起始列位置
	else
		start_position = mod(COL_WEIGHT-i,M_BASE);
    end
    
    % 列序号
    for j = start_position : -1 :start_position - COL_WEIGHT + 1 %H2中非零元素的连续5个列位置
		if(mod(j,M_BASE)==0)
			CNU_num = M_BASE;   %H2中非零元素的连续5个列位置
		else
			CNU_num = mod(j,M_BASE);
        end

		if(H_data(M_BASE-i+1,CNU_num+N_BASE-M_BASE)==-1)
			H2_shift_data(i,start_position-j+1) = PCM_MASK;
		else
			H2_shift_data(i,start_position-j+1) = H_data(M_BASE-i+1,CNU_num+N_BASE-M_BASE);
		end
    end

    %存coe
    for k = 1 : COL_WEIGHT+1
        fprintf(H2_ps,'%s',num2str(dec2bin(H2_shift_data(i,k),BLK_SIZE_WIDTH)));
    end
    fprintf(H2_ps,'\n'); 
end
fclose(H2_ps);
[flag1 ,H2_mat_exp_inv] = func_inv2 (H2_mat_exp) ;  % H2逆
%-------------------------H2_inv_value.coe------------------------
H2_inv_coe_path = strcat('./gen_coe/4k/256_2_H2_inv_value_',num2str(ROWNUM),'.coe')
%'./gen_coe/4k/256_2_H2_inv_value_16.coe' ;
H2_inv_ps = fopen(H2_inv_coe_path,'w');
fprintf(H2_inv_ps,'memory_initialization_radix = 2;\n');
fprintf(H2_inv_ps,'memory_initialization_vector =\n');

for j = 1 : M_BASE
    for k = 1 : P_PRE_CAL_NUM*BLOCK_SIZE
        % for k = (M_BASE - P_PRE_CAL_NUM)*BLOCK_SIZE + 1 : M_BASE*BLOCK_SIZE
        fprintf(H2_inv_ps,'%s',num2str(H2_mat_exp_inv(k,(j-1)*BLOCK_SIZE+1)));
    end
    fprintf(H2_inv_ps,'\n'); 
end
fclose(H2_inv_ps);









