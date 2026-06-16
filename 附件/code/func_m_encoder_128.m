% 软件编码model

function p_T = func_m_encoder_128(base_matrix,u_data_path)

	% base_matrix = load (base_matrix_path) ;
    
	q = 129 ; 
	N = size(base_matrix,2) ;   %基础矩阵列数
	M = size(base_matrix,1) ;   %基础矩阵行数
	BLOCK_SIZE = q -1 ;			%子矩阵大小

	H2_mat = base_matrix(1:M , N-M+1:N);    %H2
	H1_mat = base_matrix(1:M , 1:N-M);  %H1
	H1_mat_exp = func_gen_h_128(H1_mat,q-1);				% H1 扩展为元素为0/1的完整矩阵
	H2_mat_exp = func_gen_h_128(H2_mat,q-1);				% H2 扩展为元素为0/1的完整矩阵

	[flag1 ,H2_mat_exp_inv] = func_inv2 (H2_mat_exp) ;
    fprintf('%d',flag1);

	fid=fopen(u_data_path);
	tline = fgetl(fid);
	fclose(fid);
	U = str2num(tline(:)) ;

	r_T = mod(H1_mat_exp * U , 2);   %状态机第一步输出结果


    % p_pre_T_1 = mod(matlab( (M-3)*(q-1)+1 , 1:64 ) * r_T(1:64) , 2);  %状态机第二步的输出结果

	p_pre_T = mod(H2_mat_exp_inv( (M-3)*(q-1)+1:M*(q-1) , :) * r_T , 2);  %状态机第二步的输出结果
    p_pre_T_end = mod(H2_mat_exp_inv( 1:3*(q-1) , :) * r_T , 2);  %状态机第二步的输出结果(打孔列在后)

	p_T = mod(H2_mat_exp_inv * r_T , 2);

	p = p_T.' ;

	c = [U.' , p] ; 								%组合编码后的码字（原始信息位 + 校验位）
	H_mat_exp = [H1_mat_exp , H2_mat_exp] ;			%获得完整的校验矩阵
	Sm = mod( c * H_mat_exp.' , 2 ) ; 				%生成错误图样

	error_bit_num = 0 ;
	for i = 1:(M * BLOCK_SIZE)
		if Sm(1, i) ~= 0
			error_bit_num = error_bit_num + 1 ;
		end   
	end

	if error_bit_num == 0
		disp('dui');
	else
		fprintf('码字生成错误\n');
	end
	
end

