% 将数据由二进制转换到十六进制，并打印

function r_str = func_bin2hex(data_bin, out_path_fid)   %将输入数据打印输出到已打开文件
														%输入数据长度需为4的整数倍
	data_len = size(data_bin,1);  %获得输入二进制数据长度
	for t = 1:4:data_len-1
		temp = data_bin(t , 1 ) * 2^3 +  data_bin(t +1 , 1 ) * 2^2 +  data_bin(t+2 , 1 ) * 2 +  data_bin(t +3 , 1 ) ;
		temp = lower(dec2hex(temp));
		fprintf(out_path_fid,'%s',temp);
	end
	
end