function DemoAnalyzeData(originalData)
% 实时模式下的数据分析
%   输入参数originalData为原始数据
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global MAX_X_CNT; % 横坐标长度
global gXCntAxes1; % 坐标1的X轴计数器
global gHandlesMFig; % 主窗口句柄

global gDataAxes1; % 坐标1的数据
global gDataAxes2; % 坐标2的数据
global gDataAxes3; % 坐标3的数据

global gWaveGap; % 波形间隙

global gAxes1XLeft;  % 坐标1左半部分波形的横坐标
global gAxes1XRight; % 坐标1右半部分波形的横坐标
global gAxes1YLeft;  % 坐标1左半部分波形的纵坐标
global gAxes1YRight; % 坐标1右半部分波形的纵坐标

global gAxes2XLeft;  % 坐标2左半部分波形的横坐标
global gAxes2XRight; % 坐标2右半部分波形的横坐标
global gAxes2YLeft;  % 坐标2左半部分波形的纵坐标
global gAxes2YRight; % 坐标2右半部分波形的纵坐标

global gAxes3XLeft;  % 坐标3左半部分波形的横坐标
global gAxes3XRight; % 坐标3右半部分波形的横坐标
global gAxes3YLeft;  % 坐标3左半部分波形的纵坐标
global gAxes3YRight; % 坐标3右半部分波形的纵坐标

global gAxes4X; % 坐标4横坐标
global gAxes4Y; % 坐标4纵坐标

global gOutXMax; % X轴计数器第一次等于X轴最大值（2048）标志
    
if gXCntAxes1 > MAX_X_CNT && gOutXMax == 0
    gOutXMax = 1; % X轴计数器满足第一次等于X轴最大值（2048）条件
end

if gXCntAxes1 > MAX_X_CNT % 判断是否接收满一屏数据
    % 接收满一屏数据时计算心率，并更新窗口显示
    hr = CalcHeartRate(gDataAxes1);
    if hr ~= -100
        set(gHandlesMFig.text_hr, 'String', num2str(hr)); % 正常值
    else
        set(gHandlesMFig.text_hr, 'String', '---'); % -100代表无效值
    end
    
    gXCntAxes1 = gXCntAxes1 - MAX_X_CNT;
end

gDataAxes1(gXCntAxes1) = originalData;  

if rem(gXCntAxes1, 10) == 0        
    gAxes1XLeft = 1 : gXCntAxes1;            
    gAxes1XRight = gXCntAxes1 + gWaveGap : MAX_X_CNT;            
    gAxes1YLeft = gDataAxes1(gAxes1XLeft); 
    gAxes1YRight = gDataAxes1(gAxes1XRight);  
         
    gDataAxes2 = NotchFilterECG(gDataAxes1); % 设计陷波器并去除心电工频干扰
    gAxes2XLeft = 1 : gXCntAxes1;
    gAxes2XRight = gXCntAxes1 + gWaveGap : MAX_X_CNT;
    gAxes2YLeft = gDataAxes2(gAxes2XLeft);
    gAxes2YRight = gDataAxes2(gAxes2XRight);
    
    gDataAxes3 = FilterECG(gDataAxes1); % 使用IIR或FIR滤波器进行滤波         
    gAxes3XLeft = 1 : gXCntAxes1;         
    gAxes3XRight = gXCntAxes1 + gWaveGap : MAX_X_CNT;
    gAxes3YLeft = gDataAxes3(gAxes3XLeft);
    gAxes3YRight = gDataAxes3(gAxes3XRight);              

    [x, y] = CalcAmpSpec(gDataAxes1); % 计算心电信号的归一化幅度谱
    gAxes4X = x; % Fs * (0 : halfL) / L; % 横坐标为频率值，单位为Hz
    gAxes4Y = y; % absData(1 : halfL + 1) / maxVal; % 纵坐标为归一化幅度值，最大值为1 
end 
     
gXCntAxes1 = gXCntAxes1 + 1;

