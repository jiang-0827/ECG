function [errFlag, unpackOut] = Unpack(unpackIn)
% 对数据进行解包
%   输入参数unpackIn，解包前的数据
%   输出参数errFlag，如果解包成功则为0，如果解包失败则为1
%   输出参数unpackOut，如果解包成功则为解包后的数据包，如果解包失败则为0
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

% 解包前的数据包长为10个字节，不为10个字节的包即为错误包，将返回值赋值为0，然后退出函数
if length(unpackIn) ~= 10
    unpackOut = 0;
    return;
end

checkSum = unpackIn(1); % 第一个字节为模块ID，取出模块ID，赋值给校验和变量
dataHead = unpackIn(2); % 第二个字节为数据头，取出数据头，赋值给数据头变量

checkSum = checkSum + dataHead; % 校验和变量与数据头变量相加，再赋值给新的校验和变量

for i = 2 : 1 : 8
    checkSum = checkSum + unpackIn(i + 1); % 将数据依次与校验和变量相加，再赋值给新的校验和变量
    unpackIn(i) = bitor(bitand(unpackIn(i + 1) , 127), bitshift(bitand(dataHead , 1) , 7));
    dataHead = bitshift(dataHead, -1); % 数据头右移一位
end

if bitand(checkSum , 127) ~= bitand(unpackIn(10), 127) % 如果校验和出错
    unpackOut = 0; % 将返回值赋值为0
    errFlag = 1; % 解包失败
    return; % 然后退出函数
else
    errFlag = 0; % 解包成功
    unpackOut = unpackIn; % 如果校验和正确，则将packIn变量（保存着解包结果）赋值给输出参数
end