% ��������model

function [p_T,r_T,U] = func_m_encoder(base_matrix,u_data_path)

	% base_matrix = load (base_matrix_path) ;
    
	q = 257 ; 
	N = size(base_matrix,2) ;   %������������
	M = size(base_matrix,1) ;   %������������
	BLOCK_SIZE = q -1 ;			%�Ӿ����С

	H2_mat = base_matrix(1:M , N-M+1:N);    %H2
	H1_mat = base_matrix(1:M , 1:N-M);  %H1
	H1_mat_exp = func_gen_h(H1_mat,q-1);				% H1 ��չΪԪ��Ϊ0/1����������
	H2_mat_exp = func_gen_h(H2_mat,q-1);				% H2 ��չΪԪ��Ϊ0/1����������

	fid=fopen(u_data_path);
	tline = fgetl(fid);
	fclose(fid);
	U = str2num(tline(:)) ;

	r_T = mod(H1_mat_exp * U , 2);   %״̬����һ��������
	%将r_T每一行输出到文件 16进制形式
	fid = fopen('C:\Users\10197\Desktop\LDPC_ENCODER\4KV1_LDPC\MatlabAndCsrc\Encoder\out_soft\256\r_T.txt','w');
	%依次计算每256个bit的r_T
	for i = 1:N-M
		%取前i*256个bit
		U_temp = U(1:i*BLOCK_SIZE);
		%取矩阵的前i*256列
		H1_mat_exp_temp = H1_mat_exp(:,1:i*BLOCK_SIZE);
		%计算r_T_temp
		r_T_temp = mod(H1_mat_exp_temp * U_temp , 2);
		%输出到文件
		k = mod(i-1, 16);
		r_T_temp = cycle_shifter(k, r_T_temp.');
		func_bin2hex(r_T_temp.', fid);
		fprintf(fid,'\n');
	end

	% p_pre_T_1 = mod(matlab( (M-3)*(q-1)+1 , 1:64 ) * r_T(1:64) , 2);  %״̬���ڶ�����������
	
	
	for i = 1:M
		func_bin2hex(r_T((i-1)*BLOCK_SIZE + 1 : i*BLOCK_SIZE, 1), fid);
		fprintf(fid,'\n');
	end
	fclose(fid);
	[flag1 ,H2_mat_exp_inv] = func_inv2 (H2_mat_exp) ;
    fprintf('%d',flag1);
    % p_pre_T_1 = mod(matlab( (M-3)*(q-1)+1 , 1:64 ) * r_T(1:64) , 2);  %״̬���ڶ�����������

	p_pre_T = mod(H2_mat_exp_inv( (M-3)*(q-1)+1:M*(q-1) , :) * r_T , 2);  %״̬���ڶ�����������
    p_pre_T_end = mod(H2_mat_exp_inv( 1:3*(q-1) , :) * r_T , 2);  %״̬���ڶ�����������(������ں�)

	p_T = mod(H2_mat_exp_inv * r_T , 2);

	p = p_T.' ;

	c = [U.' , p] ; 								%��ϱ��������֣�ԭʼ��Ϣλ + У��λ��
	H_mat_exp = [H1_mat_exp , H2_mat_exp] ;			%���������У�����
	Sm = mod( c * H_mat_exp.' , 2 ) ; 				%���ɴ���ͼ��

	error_bit_num = 0 ;
	for i = 1:(M * BLOCK_SIZE)
		if Sm(1, i) ~= 0
			error_bit_num = error_bit_num + 1 ;
		end   
	end

	if error_bit_num == 0
		disp('dui');
	else
		fprintf('�������ɴ���\n');
	end
	
end

%一个函数 输入向量以256位单位循环左移k次输出
function [out] = cycle_shifter(k, in)
	out = in;
	for i = 1:k
		%每次循环左移256位
		out = out([257:end, 1:256]);
	end
end