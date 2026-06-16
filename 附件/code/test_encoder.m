%%%%%%%%%����Ӳ������model�����ļ�%%%%%%%%%

%ע���޸�func_gen_h�еĲ���

clear all;

BLOCK_SIZE 	= 256 ;
u_data_path = './u_data/u_data_256_2.txt';
fid=fopen(u_data_path);
tline = fgetl(fid);
fclose(fid);
u_data = str2num(tline(:)) ;    %����


%base_matrix_path 	= './base_matrix/peg_16_145.dat' ;
qc_base_matrix_path = './base_matrix/4k/qc_peg_16_146_invc6dplopt_shift_inv.txt' ;
output_path         = './out_hard/256/o_code_data_25txt';
m_output_path         = './out_soft/256/m_o_code_data_16.txt';
m_output_path_1         = './out_soft/256/m_o_code_data_2_16.txt'; %��������ʽ��������ļ�


base_matrix = load (qc_base_matrix_path) ;
N_BASE = size(base_matrix,2);
M_BASE = size(base_matrix,1);%���У��λ����
% [base_matrix, valid_0, inv_H2] = func_full_rank_check(base_matrix, N_BASE, M_BASE, 257, 4);   %��֤��������H2����
% if(valid_0 == 0)    %���valid_0=0����˵��������
%     fprintf('irreversible!\n');
% end


% % 1��ģ��Ӳ�����루func_encoder��
% o_code_data = func_encoder_diag(base_matrix,u_data_path) ;  %P_T
% fid = fopen(output_path ,'w');
% 
% for j = 1 : N_BASE - M_BASE 
% 	func_bin2hex(u_data((j-1)*BLOCK_SIZE + 1 : j*BLOCK_SIZE, 1), fid); 
%     fprintf(fid,'\n');
% end
% 
% for j = 1 : M_BASE
% 	func_bin2hex(o_code_data((j-1)*BLOCK_SIZE + 1 : j*BLOCK_SIZE, 1), fid); 
%     fprintf(fid,'\n');
% end
% fclose(fid);

%2���������루func_m_encoder��
[m_o_code_data,r_T,U] = func_m_encoder(base_matrix,u_data_path) ;

fid = fopen(m_output_path, 'w');
fid_2_in = fopen(m_output_path_1, 'w');
 
for j = 1 : N_BASE - M_BASE 
	func_bin2hex(u_data((j-1)*BLOCK_SIZE + 1 : j*BLOCK_SIZE, 1), fid); fprintf(fid,'\n');
end

for k = 1 : N_BASE - M_BASE 
    fprintf(fid_2_in,'%s',num2str(u_data((k-1)*BLOCK_SIZE+1:k*BLOCK_SIZE)));fprintf(fid_2_in,'\n');
end

for j = 1 : M_BASE
	func_bin2hex(m_o_code_data((j-1)*BLOCK_SIZE + 1 : j*BLOCK_SIZE, 1), fid); fprintf(fid,'\n');
end
for k = 1 : M_BASE
    fprintf(fid_2_in,'%s',num2str(m_o_code_data((k-1)*BLOCK_SIZE+1:k*BLOCK_SIZE,1)));fprintf(fid_2_in,'\n');
end
fclose(fid);
fclose(fid_2_in);
