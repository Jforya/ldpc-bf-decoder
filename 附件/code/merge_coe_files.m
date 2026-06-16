function merge_coe_files(fileNames, outputFileName)
    % 初始化一个空的字符串数组来存储所有文件的内容
    allData = "";

    % 遍历所有的文件名
    for i = 1:length(fileNames)
        % 打开文件
        fileId = fopen(fileNames{i}, 'r');

        % 如果是第一个文件，我们需要读取文件头
        if i == 1
            allData = [allData, fgets(fileId)];
            allData = [allData, fgets(fileId)];
        else
            % 跳过文件头
            fgets(fileId);
            fgets(fileId);
        end

        % 读取剩余的内容并添加到 allData
        while ~feof(fileId)
            allData = [allData, fgets(fileId)];
        end

        % 关闭文件
        fclose(fileId);
    end

    % 打开输出文件
    fileId = fopen(outputFileName, 'w');

    % 写入合并后的内容
    fprintf(fileId, '%s', allData);

    % 关闭文件
    fclose(fileId);
end