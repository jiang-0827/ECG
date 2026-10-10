function InitData()
% 初始化全局变量
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gDataAxes1; % 坐标1的数据
global gDataAxes2; % 坐标2的数据
global gDataAxes3; % 坐标3的数据
global gDataAxes4; % 坐标4的数据
global gXCntAxes1; % 坐标1的X轴计数器
global gXCntAxes2; % 坐标2的X轴计数器
global gXCntAxes3; % 坐标3的X轴计数器

global MAX_X_CNT; % 横坐标长度

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

global gHandlesPlot1; % 坐标1的曲线句柄
global gHandlesPlot2; % 坐标2的曲线句柄
global gHandlesPlot3; % 坐标3的曲线句柄
global gHandlesPlot4; % 坐标4的曲线句柄

global gHandlesMFig; % 主窗口句柄

set(gHandlesMFig.text_hr, 'String', '---'); 

delete(gHandlesPlot1);
delete(gHandlesPlot2);
delete(gHandlesPlot3);
delete(gHandlesPlot4);

gAxes1XLeft  = [];
gAxes1XRight = [];
gAxes1YLeft  = [];
gAxes1YRight = [];
gAxes2XLeft  = [];
gAxes2XRight = [];
gAxes2YLeft  = [];
gAxes2YRight = [];
gAxes3XLeft  = [];
gAxes3XRight = [];
gAxes3YLeft  = [];
gAxes3YRight = [];

gXCntAxes1 = 1; % 坐标1的X轴计数器
gXCntAxes2 = 1; % 坐标2的X轴计数器
gXCntAxes3 = 1; % 坐标3的X轴计数器


gDataAxes1 =  zeros(1,MAX_X_CNT);
gDataAxes2 =  zeros(1,MAX_X_CNT);

gDataAxes3 =  zeros(1,MAX_X_CNT);
gDataAxes4 =  zeros(1,MAX_X_CNT);