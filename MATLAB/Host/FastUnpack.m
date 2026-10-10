function [errFlag, unpackOut] = FastUnpack(unpackIn)
% 对数据进行解包（快速版本，暂时不用）
%   输入参数unpackIn，解包前的数据
%   输出参数errFlag，如果解包成功则为0，如果解包失败则为1
%   输出参数unpackOut，如果解包成功则为解包后的数据包，如果解包失败则为0
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

sumRslt = dec2bin(sum(unpackIn(1 : 9))); % 前9个字节求和
sumLow7 = sumRslt(end - 6 : end); % 取出低七位
    
checkRslt = dec2bin(unpackIn(10)); % 数据包中的校验和
checkLow7 = checkRslt(end - 6 : end); % 取出低七位
    
if strcmp(sumLow7, checkLow7) % 如果校验和正确
    dataHead = dec2bin(unpackIn(2)); % 数据头转换为二进制        
    binSecID = dec2bin(unpackIn(3)); % 二级ID转换为二进制        
    binDat1  = dec2bin(unpackIn(4)); % 数据1转换为二进制
    binDat2  = dec2bin(unpackIn(5)); % 数据2转换为二进制
    binDat3  = dec2bin(unpackIn(6)); % 数据3转换为二进制
    binDat4  = dec2bin(unpackIn(7)); % 数据4转换为二进制
    binDat5  = dec2bin(unpackIn(8)); % 数据5转换为二进制
    binDat6  = dec2bin(unpackIn(9)); % 数据6转换为二进制
              
    binSecID(1) = dataHead(8); % 复原二级ID的最高位       
    binDat1(1)  = dataHead(7); % 复原数据1的最高位
    binDat2(1)  = dataHead(6); % 复原数据2的最高位
    binDat3(1)  = dataHead(5); % 复原数据3的最高位
    binDat4(1)  = dataHead(4); % 复原数据4的最高位
    binDat5(1)  = dataHead(3); % 复原数据5的最高位
    binDat6(1)  = dataHead(2); % 复原数据6的最高位

    secID = bin2dec(binSecID); % 二级ID转换为十进制
    dat1  = bin2dec(binDat1);  % 数据1转换为十进制
    dat2  = bin2dec(binDat2);  % 数据2转换为十进制
    dat3  = bin2dec(binDat3);  % 数据3转换为十进制
    dat4  = bin2dec(binDat4);  % 数据4转换为十进制
    dat5  = bin2dec(binDat5);  % 数据5转换为十进制
    dat6  = bin2dec(binDat6);  % 数据6转换为十进制 
    
    errFlag = 0; % 解包成功
    unpackOut = [unpackIn(1), secID, dat1, dat2, dat3, dat4, dat5, dat6]; % 解包结果       
else % 如果校验和错误
    errFlag = 1; % 解包失败
    unpackOut = 0; % 解包失败将其赋值为0
end