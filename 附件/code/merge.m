% 
%128_1_H1_value
%128_1_H2_value
%128_1_H2_inv_value

%256_2_H1_value
%256_2_H2_value
%256_2_H2_inv_value

filename = '256_2_H2_inv_value';

FILE_FOLDER = 'D:\yangli\RS-LDPC\bsqcldpc\bsdecoderVsrc\4KV1_LDPC\MatlabAndCsrc\Encoder\gen_coe\';

CODE_LENGTH = '4k';

%定义输入文件的路径
file_paths = {
    %strcat(FILE_FOLDER,'26_155_',CODE_LENGTH,'\', filename),
    %strcat(FILE_FOLDER,'22_151_',CODE_LENGTH,'\', filename),
    %strcat(FILE_FOLDER,'21_150_',CODE_LENGTH,'\', filename),
    %strcat(FILE_FOLDER,'20_149_',CODE_LENGTH,'\', filename)
    
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_25.coe'),
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_23.coe'),
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_20.coe'),
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_19.coe'),
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_17.coe'),
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_15.coe'),
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_14.coe'),
    strcat(FILE_FOLDER,CODE_LENGTH,'\', filename,'_11.coe')
    % 添加更多文件路径...
};
    % 添加更多文件路径... 21_150_4K 20_149_4K

% 定义输出文件的路径
output_path =strcat(FILE_FOLDER,'merged_',CODE_LENGTH,'_',filename,'.coe'); 
for i = 1:length(file_paths)
    if exist(file_paths{i}, 'file') ~= 2
        fprintf('File %s does not exist.\n', file_paths{i});
    end
end
% 调用函数
merge_coe_files(file_paths, output_path);
