function [x, y] = CalcAmpSpec(dataIn)
% 计算心电信号的归一化幅度谱
%   输入参数dataIn为心电波的采样值
%   输出参数x和y分别为幅度谱的横坐标序列，以及与横坐标序列对应的归一化幅度
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

Fs = 500; % 采样频率
L = length(dataIn); % 信号长度
halfL = round(L / 2); % 幅度谱是对称的，因此只需要绘制一半即可
fftRslt = fft(dataIn - nanmean(dataIn)); % 去除直流分量，然后再进行傅里叶变换
absData = abs(fftRslt); % 计算幅度谱
maxVal  = max(absData); % 计算最大值  
        
x = Fs * (0 : halfL) / L; % 横坐标为频率值，单位为Hz
y = absData(1 : halfL + 1) / maxVal; % 纵坐标为归一化幅度值，最大值为1