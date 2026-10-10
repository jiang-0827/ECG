function dataOut = FilterECG(dataIn)
% 使用IIR或FIR滤波器进行滤波
%   输入参数dataIn为滤波前的数据
%   输出参数dataOut为滤波后的数据
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gFiltType; %滤波器类型，1-IIR滤波器，2-FIR滤波器
global gFiltDegree; % 滤波器阶数
global gFiltFc; % 滤波器截止频率
global gFiltStartData; % 滤波数据的头
global gOutXMax; % X轴计数器第一次等于X轴最大值（2048）标志

global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式

dataOut = [];

if gOutXMax == 1 && gDemoFlag == 0 % 串口模式下，且数据超过X轴最大值
    gFiltStartData = dataIn(1801 : 2048);
elseif gOutXMax == 0 && gDemoFlag == 0 % 串口模式下，且数据未超过X轴最大值
    gFiltStartData = zeros(1, 248);
end

dataIn = [gFiltStartData, dataIn];

if gFiltType == 1 % IIR滤波器
    Fs = 500; % 采样频率
    Wc = gFiltFc / (Fs / 2); % 归一化截止频率
    [b, a] = butter(gFiltDegree, Wc); % 设计低通滤波器
    dataOut = filter(b, a, dataIn); % 滤波
elseif gFiltType == 2 % FIR滤波器
    Fs = 500; % 采样频率
    Wc = gFiltFc / (Fs / 2); % 归一化截止频率
    b = fir1(gFiltDegree, Wc); % 设计低通滤波器
    dataOut = filter(b, 1, dataIn); % 滤波  
end
dataOut(1: length(gFiltStartData)) = []; % 将滤波数据的头清零
