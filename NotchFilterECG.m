function dataOut = NotchFilterECG(dataIn)
% 设计陷波器并去除心电工频干扰
%   输入参数dataIn为原始心电波形
%   输出参数dataOut为陷波器处理后的波形
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

Fs = 500;    % 采样频率
T = 1 / Fs; % 采样间隔
Fc = 50;     % 陷波频率

alpha = -2 * cos(2 * pi * Fc * T);         
beta  = 0.96;
b = [1, alpha, 1];
a = [1, alpha * beta, beta^2];

dataOut = dlsim(b, a, dataIn);
