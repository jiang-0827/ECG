function heartRate = CalcHeartRate(dataIn)
% 计算心率
%   输入参数dataIn为波形数据
%   输出参数heartRate为心率
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

MIN_HEART_RATE = 0;   % 心率最小值
MAX_HEART_RATE = 300; % 心率最大值

[~, index] = findpeaks(dataIn, 'minpeakdistance', 250, 'minpeakheight', max(dataIn) - 200);

arrX = zeros(length(index) - 1, 1); % 预分配内存
for iCnt = 1 : length(index) - 1
    arrX(iCnt) = (index(iCnt + 1) - index(iCnt));
end

medianY = median(arrX); % 求数组的中值
heartRate = int16(30000 / medianY); % 转换为bpm为单位的心率值，并取值为整数

if (heartRate < MIN_HEART_RATE) || (heartRate > MAX_HEART_RATE)
    heartRate = int16(-100); % 赋值为无效值
end 