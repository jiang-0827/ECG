function varargout = ECG(varargin)
% ECG MATLAB code for ECG.fig
%      ECG, by itself, creates a new ECG or raises the existing
%      singleton*.
%
%      H = ECG returns the handle to a new ECG or the handle to
%      the existing singleton*.
%
%      ECG('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in ECG.M with the given input arguments.
%
%      ECG('Property','Value',...) creates a new ECG or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ECG_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ECG_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ECG

% Last Modified by GUIDE v2.5 31-Mar-2020 18:13:14

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ECG_OpeningFcn, ...
                   'gui_OutputFcn',  @ECG_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

% --- Executes just before ECG is made visible.
function ECG_OpeningFcn(hObject, eventdata, handles, varargin)
% Choose default command line output for EC
% 
% G
handles.output = hObject;
set(gcf, 'numbertitle', 'off', 'name', 'LY-A501心电信号处理MATLAB软件系统-V1.0'); % 主界面外观
movegui('center'); % 将窗口置于屏幕中间
addpath(genpath(pwd)); % 将当前文件夹下的所有文件夹都包括进调用函数的目录
global gHandlesMFig; % 主窗口句柄
gHandlesMFig = handles; % 获取主窗口句柄

global gStartFlag; % 开始采样或开始演示标志，0-停止采样或停止演示，1-开始采样或开始演示
gStartFlag = 0; % 默认为停止采样或停止演示

global gDemoTimer; % 文件数据回放演示定时器
global gRealTimer; % 串口数据实时绘制定时器
gDemoTimer = timer('TimerFcn', {@DemoDraw, handles}, 'Period', 0.001, ...
    'ExecutionMode', 'fixedDelay', 'StartDelay', 0.001);  
gRealTimer = timer('TimerFcn', {@RealDraw, handles}, 'Period', 0.1, ...
    'ExecutionMode', 'fixedRate'); 

global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式
gDemoFlag = 0; % 默认为串口模式

global MAX_X_CNT; % 横坐标长度
MAX_X_CNT = 2048; % 横坐标长度为2048，横坐标长度为常量

global gUARTOpenFlag; % 串口开启标志，0-串口为关闭状态，1-串口为开启状态
gUARTOpenFlag = 0; % 默认为关闭状态

global gRdFinishFlag; % 用于演示模式，读取完成时置为1
gRdFinishFlag = 0; % 默认为0，表示未读取完成

global gYShift; % 调整垂直位置时对应的Y轴移位值
global gYScale; % 纵坐标范围

global gWaveGap;  % 波形间隙
global gWaveRatio; % 波形比例
global gLocValue; % 垂直位置弹出式菜单value属性值
global gRatioValue; % 波形比例弹出式菜单value属性值

gYScale = [0, 4096]; % 纵坐标范围默认为0-4096
gYShift = 0; % Y轴移位值默认为0
gWaveGap = 10; % 波形间隙默认为10

gWaveRatio = 1; % 波形比例默认为1
gLocValue = 5; % 垂直位置弹出式菜单value属性值默认为5
gRatioValue = 3; % 波形比例弹出式菜单value属性值默认为3

set(handles.popupmenu_ratio, 'value', gRatioValue); 
set(handles.popupmenu_loc, 'value', gLocValue); 

global gXCntAxes1; % 坐标1的X轴计数器
global gXCntAxes2; % 坐标2的X轴计数器
global gXCntAxes3; % 坐标3的X轴计数器

gXCntAxes1 = 1; % 初始值为1
gXCntAxes2 = 1; % 初始值为1
gXCntAxes3 = 1; % 初始值为1

global gDataAxes1; % 坐标1的数据
global gDataAxes2; % 坐标2的数据
global gDataAxes3; % 坐标3的数据
global gDataAxes4; % 坐标4的数据

gDataAxes1 =  zeros(1, MAX_X_CNT);
gDataAxes2 =  zeros(1, MAX_X_CNT);
gDataAxes3 =  zeros(1, MAX_X_CNT);
gDataAxes4 =  zeros(1, MAX_X_CNT);

global gFiltType; %滤波器类型，1-IIR滤波器，2-FIR滤波器
global gFiltDegree; % 滤波器阶数
global gFiltFc; % 滤波器截止频率

global gOutXMax; % X轴计数器第一次等于X轴最大值（2048）标志
global gFiltStartData; % 滤波数据的头
gFiltStartData = zeros(1, 248);
gFiltType = 1; % 默认为IIR滤波器
gFiltDegree = 5; % 滤波器阶数默认为5
gFiltFc = 20; % 滤波器截止频率默认为20

gOutXMax = 0; % X轴计数器不满足第一次等于X轴最大值（2048）条件

global gFFTFlag; % 判定主界面中是否勾选FFT选项
gFFTFlag = 1; % 默认情况下为已勾选FFT选项

global gSaveAxes1Data; % 保存坐标1数据变量
global gSaveAxes2Data; % 保存坐标2数据变量
global gSaveAxes3Data; % 保存坐标3数据变量
global gSaveAxes4Data; % 保存坐标4数据变量
global gSaveDemoData;  % 保存演示数据变量

global gSaveDataFlag; % 保存已选数据标志
global gSaveAxes1Flag; % 保存坐标1数据标志
global gSaveAxes2Flag; % 保存坐标2数据标志
global gSaveAxes3Flag; % 保存坐标3数据标志
global gSaveAxes4Flag; % 保存坐标4数据标志
global gSaveDemoFlag;  % 保存演示数据标志

gSaveDataFlag  = 0; % 默认为不保存数据
gSaveAxes1Flag = 0; % 默认为不保存坐标1
gSaveAxes2Flag = 0; % 默认为不保存坐标2
gSaveAxes3Flag = 0; % 默认为不保存坐标3
gSaveAxes4Flag = 0; % 默认为不保存坐标4
gSaveDemoFlag  = 0; % 默认为不保存演示数据

gSaveAxes1Data = []; % 清空
gSaveAxes2Data = []; % 清空
gSaveAxes3Data = []; % 清空
gSaveAxes4Data = []; % 清空            
gSaveDemoData  = []; % 清空      

global gCmdRstAck;     % 模块复位信息应答命令
global gCmdModuleType; % 模块类型设置命令
global gCmdGetBLine;   % 获取基线命令
global gCmdStopSamp;   % 停止采样命令
global gCmdStartSamp;  % 开始采样命令

% 十六进制命令：01 81 81 80 80 80 80 80 80 83（解包格式：01 81 80 80 80 80 80 80）
gCmdRstAck     = [1  129 129 128 128 128 128 128 128 131]; % 模块复位信息应答命令
% 十六进制命令：01 81 91 B0 80 80 80 80 80 C3（解包格式：01 91 30 00 00 00 00 00）                
gCmdModuleType = [1  129 145 176 128 128 128 128 128 195]; % 模块类型设置命令
% 十六进制命令：30 81 82 80 80 80 80 80 80 B3（解包格式：30 82 00 00 00 00 00 00）
gCmdGetBLine   = [48 129 130 128 128 128 128 128 128 179]; % 获取基线命令
% 十六进制命令：30 81 81 80 80 80 80 80 80 B2（解包格式：30 81 00 00 00 00 00 00） 
gCmdStopSamp   = [48 129 129 128 128 128 128 128 128 178]; % 停止采样
% 十六进制命令：30 81 81 81 80 80 80 80 80 B3（解包格式：30 81 01 00 00 00 00 00）            
gCmdStartSamp  = [48 129 129 129 128 128 128 128 128 179]; % 开始采样
                  
UpdateAxesRange(handles.axes1); % 更新坐标范围
UpdateAxesRange(handles.axes2); % 更新坐标范围
UpdateAxesRange(handles.axes3); % 更新坐标范围
UpdateAxesRange(handles.axes4); % 更新坐标范围

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ECG wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = ECG_OutputFcn(hObject, eventdata, handles) 
% Get default command line output from handles structure
varargout{1} = handles.output;

% --------------------------------------------------------------------
function menu_set_uart_Callback(hObject, eventdata, handles)
global gSerial; % 串口对象
global gUARTOpenFlag; % 串口开启标志，0-串口为关闭状态，1-串口为开启状态

global gClosedFigFlag;    % 弹出的窗口关闭标志，0-未关闭，1-已关闭
gClosedFigFlag = 0;       % 将窗口关闭标志置为0
SetUART;                  % 打开窗体设置窗体
while gClosedFigFlag == 0 % 等待数据读取窗体关闭
    pause(1);             % 延时等待
end
%设置串口关闭窗体后的回调
disp('start to handle Serial');
if gUARTOpenFlag == 1 % 执行打开串口操作
    s=get(gSerial,'Status');  % 先获取当前串口状态
    if strcmp(s,'closed') == 1 % 打开串口前判断，避免在串口己打开的情况下，在串口设置界面按取消还继续执行打开
        try
            fopen(gSerial); % 打开串口
            ResetStatus(handles,0);   % 若是演示模式，则重置状态
            uartstr = strcat('串口状态：',get(gSerial,'Port'),'已打开');  
            set(handles.text_uartinfo,'String',uartstr);   % 左下角显示串口状态信息
            % SendCmd(gCmdStopSamp); % 发送心电停止采样命令
        catch
            gUARTOpenFlag = 0; % 将串口打开标志置为未打开
            uartstr = strcat('串口状态：','关闭');          
            set(handles.text_uartinfo,'String',uartstr);   % 左下角显示串口状态信息
        end
    else
        disp('serial port already open!');
    end
else
    disp('close uart');
end

% --------------------------------------------------------------------
function menu_save_Callback(hObject, eventdata, handles)
global gStartFlag; % 当前状态

if gStartFlag == 0
    SaveData; % 打开数据存储窗口
else
    helpdlg('先停止采样，再设置！', '提示');
end

% --------------------------------------------------------------------
function menu_demo_Callback(hObject, eventdata, handles)
global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式
gDemoFlag = 0; % 默认为串口模式
ReadData; % 打开数据演示窗口
ResetStatus(handles, 1);   % 复位运行状态

function ResetStatus(handles, mode)
%复位运行状态 
%mode: 1：演示， 0：串口
global gRealTimer;
global gDemoTimer;
global gStartFlag;
global gSerial; % 串口对象
global gUARTOpenFlag; % 将串口打开标志置为未打开
global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式

disp('gDemoFlag');
disp(gDemoFlag);
if mode == 1 % 切换为演示模式
    switch get(gRealTimer, 'Running')    %暂停timer
        case 'on'
            stop(gRealTimer); % 如果实时模式定时器在运行，则将其关闭
            set(handles.pushbutton_sample,'String','开始采样');
            gStartFlag = 0;
            OperateFile(0); % 关闭文件
    end
    % 关闭串口
    try
        s = get(gSerial,'Status');
        disp(s);
        if strcmp(s,'open') == 1 % 串口打开
            try
                fclose(gSerial);
                set(handles.text_uartinfo,'String','串口状态：关闭');   % 左下角显示串口状态信息
                gUARTOpenFlag = 0; % 将串口打开标志置为未打开
            catch
            end
        end
    catch
    end
else      %切换串口模式
%     switch get(gRealTimer, 'Running')    %暂停timer
%         case 'on'
%             stop(gRealTimer); % 如果实时模式定时器在运行，则将其关闭
%             set(handles.pushbutton_sample,'String','开始采样');
%             gStartFlag = 0;
%     end
try
    switch get(gDemoTimer, 'Running')
        case 'on'
            stop(gDemoTimer); % 如果演示模式定时器在运行，则将其关闭
            gStartFlag = 0;
    end
catch
end
    
end

% --------------------------------------------------------------------
function menu_about_Callback(hObject, eventdata, handles)
hMain = helpdlg({'LY-A501型医学信号处理平台', '心电信号处理MATLAB软件系统', ' ', '版本:V1.0.0',...
    '深圳市乐育科技有限公司','www.leyutek.com'}, '关于');
set(hMain, 'windowstyle', 'modal'); % 设置为模态对话框
hChild = get(hMain, 'children');
hText = findall(hChild, 'type', 'text');
set(hText, 'fontsize', 9); % 设置字体

% --------------------------------------------------------------------
function menu_exit_Callback(hObject, eventdata, handles)
btn = questdlg('是否确认退出？', '退出', '确定', '取消', '确定');
if strcmp(btn, '确定') % 如果单击的是“确认”按钮
    ReleaseAll(); % 释放资源
    close all; % 关闭所有窗口
end

% --- Executes on selection change in popupmenu_ratio.
function popupmenu_ratio_Callback(hObject, eventdata, handles)
global gRatioValue % 波形比例弹出式菜单value属性值
global gYScale; % 纵坐标范围
global gWaveRatio; % 波形比例
gRatioValue = get(handles.popupmenu_ratio, 'value'); % 获取波形比例弹出式菜单value属性值

switch(gRatioValue)
    case 1
        gYScale = [-2048 * 2, 2048 * 4]; % X1/4
        gWaveRatio = 0.25; 
    case 2
        gYScale = [-2048, 2048 * 3]; % X1/2
        gWaveRatio = 0.5;
    case 3
        gYScale = [0, 4096]; % X1
        gWaveRatio = 1;               
    case 4
        gYScale = [1024, 3072]; % X2
        gWaveRatio = 2;
    case 5
        gYScale = [1536, 2560]; % X4
        gWaveRatio = 4;
end


% --- Executes during object creation, after setting all properties.
function popupmenu_ratio_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_ratio (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in popupmenu_loc.
function popupmenu_loc_Callback(hObject, eventdata, handles)
global gYShift; % 调整垂直位置时对应的Y轴移位值
global gWaveRatio; % 波形比例
global gLocValue; % 垂直位置弹出式菜单value属性值

gLocValue = get(handles.popupmenu_loc, 'value'); % 获取垂直位置弹出式菜单value属性值
gYShift = (5 - gLocValue) .* 512 / gWaveRatio; % 计算调整垂直位置时对应的Y轴移位值


% --- Executes during object creation, after setting all properties.
function popupmenu_loc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu_loc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in radiobutton_iir.
function radiobutton_iir_Callback(hObject, eventdata, handles)
global gFiltType; %滤波器类型，1-IIR滤波器，2-FIR滤波器
global gFiltDegree; % 滤波器阶数
global gFiltFc; % 滤波器截止频率

set(handles.radiobutton_iir, 'value', 1);
set(handles.radiobutton_fir, 'value', 0);
if get(hObject,'value') == 1
    gFiltType = 1; % IIR滤波器
    gFiltFc = str2double(get(handles.edit_iir_fc, 'string'));
    gFiltDegree = str2double(get(handles.edit_iir_degree, 'string'));
end

% --- Executes on button press in radiobutton_fir.
function radiobutton_fir_Callback(hObject, eventdata, handles)
global gFiltType; %滤波器类型，1-IIR滤波器，2-FIR滤波器
global gFiltDegree; % 滤波器阶数
global gFiltFc; % 滤波器截止频率

set(handles.radiobutton_iir,'value',0);
set(handles.radiobutton_fir,'value',1);
if get(hObject,'value') == 1
    gFiltType = 2; % FIR滤波器
    gFiltFc = str2double(get(handles.edit_fir_fc, 'string'));
    gFiltDegree = str2double(get(handles.edit_fir_degree, 'string'));
end

function edit_iir_fc_Callback(hObject, eventdata, handles)
global  gFiltFc; % 滤波器截止频率
gFiltFc = str2double(get(handles.edit_iir_fc, 'string'));

% --- Executes during object creation, after setting all properties.
function edit_iir_fc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_iir_fc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit_fir_fc_Callback(hObject, eventdata, handles)
global  gFiltFc; % 滤波器截止频率
gFiltFc = str2double(get(handles.edit_fir_fc, 'string'));

% --- Executes during object creation, after setting all properties.
function edit_fir_fc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_fir_fc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit_iir_degree_Callback(hObject, eventdata, handles)
global gFiltDegree; % 滤波器阶数
gFiltDegree = str2double(get(handles.edit_iir_degree, 'string'));

% --- Executes during object creation, after setting all properties.
function edit_iir_degree_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_iir_degree (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function edit_fir_degree_Callback(hObject, eventdata, handles)
global gFiltDegree; % 滤波器阶数
gFiltDegree = str2double(get(handles.edit_fir_degree, 'string'));

% --- Executes during object creation, after setting all properties.
function edit_fir_degree_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_fir_degree (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in checkbox_fft.
function checkbox_fft_Callback(hObject, eventdata, handles)
global gFFTFlag; % 判定主界面中是否勾选FFT选项
if get(hObject, 'Value') == 1
    gFFTFlag = 1; % 如果已勾选，将gFFTFlag设置为1
else
    gFFTFlag = 0; % 如果未勾选，将gFFTFlag设置为0
end

function edit_fft_n_Callback(hObject, eventdata, handles)
% hObject    handle to edit_fft_n (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_fft_n as text
%        str2double(get(hObject,'String')) returns contents of edit_fft_n as a double


% --- Executes during object creation, after setting all properties.
function edit_fft_n_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_fft_n (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton1.
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% --- Executes on button press in pushbutton_sample.
function pushbutton_sample_Callback(hObject, eventdata, handles)
global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式
global gStartFlag; % 开始采样或开始演示标志，0-停止采样或停止演示，1-开始采样或开始演示
global gUARTOpenFlag; % 串口开启标志，0-串口为关闭状态，1-串口为开启状态

global gCmdRstAck;     % 模块复位信息应答命令
global gCmdModuleType; % 模块类型设置命令
global gCmdStopSamp;   % 停止采样
global gCmdStartSamp;  % 开始采样

if gStartFlag == 0 % 如果当前为停止采样或停止演示，即按钮上显示开始采样或开始演示
    gStartFlag = 1; % 当前状态设置为开始采样或开始演示
    if gDemoFlag == 1 % 演示模式
        set(handles.pushbutton_sample, 'string', '停止演示'); % 将按钮名设置为停止演示       
        OperateTimer(1); % 启动演示模式定时器
    else % 实时模式
        if gUARTOpenFlag == 1
            OperateFile(1); % 打开或创建文件           
            SendCmd(gCmdRstAck); % 发送模块复位信息应答命令                 
            SendCmd(gCmdModuleType); % 发送模块类型设置命令                    
            SendCmd(gCmdStartSamp); % 发送心电开始采样命令            
            set(handles.pushbutton_sample, 'string', '停止采样'); % 将按钮名设置为停止采样          
            OperateTimer(1); % 启动实时模式定时器
        else
            gStartFlag  = 0; % 当前状态设置为停止采样或停止演示
            helpdlg('串口未打开', '提示');
        end
    end
else
    gStartFlag = 0; % 当前状态设置为停止采样或停止演示
    if gDemoFlag == 1 % 演示模式
        set(handles.pushbutton_sample, 'string', '开始演示'); % 将按钮名设置为开始演示
    else % 实时模式
        if gUARTOpenFlag == 1          
            SendCmd(gCmdStopSamp); % 发送心电停止采样命令        
        end
        set(handles.pushbutton_sample, 'string', "开始采样"); % 将按钮名设置为开始采样
        OperateFile(0); % 关闭文件
    end  
    OperateTimer(0); % 关闭定时器
end

function OperateTimer(onFlag)
% 启动或关闭定时器
%   输入参数onFlag为启动或关闭开关，0-关闭，1-启动
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式
global gDemoTimer; % 文件数据回放演示定时器
global gRealTimer; % 串口数据实时绘制定时器

global gRdFinishFlag; % 用于演示模式，读取完成时置为1

if onFlag == 1 % 启动定时器
    InitData(); % 初始化全局变量
    if gDemoFlag == 1 % 演示模式，确保最终启动演示模式定时器，并关闭实时模式定时器
        disp("演示模式");
        gRdFinishFlag = 0; % 表示未读取完成        
        switch get(gRealTimer, 'Running')
            case 'on'
                stop(gRealTimer); % 如果实时模式定时器在运行，则将其关闭
        end
        switch get(gDemoTimer, 'Running')
            case 'off'
                start(gDemoTimer); % 如果演示模式定时器已关闭，则将其启动
        end
    else % 实时模式，确保最终启动实时模式定时器，并关闭演示模式定时器
        disp("实时模式");     
        switch get(gDemoTimer, 'Running')
            case 'on'
                stop(gDemoTimer); % 如果演示模式定时器在运行，则将其关闭
        end
        switch get(gRealTimer, 'Running')
            case 'off'
                start(gRealTimer); % 如果实时模式定时器已关闭，则将其启动
        end
    end
else % 关闭定时器
    if gDemoFlag == 1 % 演示模式
        disp("演示模式");
        switch get(gDemoTimer, 'Running')
            case 'on'
                stop(gDemoTimer); % 如果演示模式定时器在运行，则将其关闭
        end
    else % 实时模式
        disp("实时模式");
        switch get(gRealTimer, 'Running')
            case 'on'
                stop(gRealTimer); % 如果实时模式定时器在运行，则将其关闭
        end
    end
end

% --- Executes on selection change in popupmenu4.
function popupmenu4_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu4 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu4

% --- Executes during object creation, after setting all properties.
function popupmenu4_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in popupmenu5.
function popupmenu5_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu5 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu5


% --- Executes during object creation, after setting all properties.
function popupmenu5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in popupmenu6.
function popupmenu6_Callback(hObject, eventdata, handles)
% hObject    handle to popupmenu6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns popupmenu6 contents as cell array
%        contents{get(hObject,'Value')} returns selected item from popupmenu6

% --- Executes during object creation, after setting all properties.
function popupmenu6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to popupmenu6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function RealDraw(~, ~, handles)
% 实时模式下绘制波形
%   输入参数handles
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

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

global gHandlesPlot1; % 坐标1的曲线句柄
global gHandlesPlot2; % 坐标2的曲线句柄
global gHandlesPlot3; % 坐标3的曲线句柄
global gHandlesPlot4; % 坐标4的曲线句柄

global gSaveAxes1Flag; % 保存坐标1数据标志
global gSaveAxes2Flag; % 保存坐标2数据标志
global gSaveAxes3Flag; % 保存坐标3数据标志
global gSaveAxes4Flag; % 保存坐标4数据标志
global gSaveDemoFlag;  % 保存演示数据标志

global gSaveAxes1Data; % 保存坐标1数据变量
global gSaveAxes2Data; % 保存坐标1数据变量
global gSaveAxes3Data; % 保存坐标1数据变量
global gSaveAxes4Data; % 保存坐标1数据变量
global gSaveDemoData;  % 保存演示数据变量

global gHandlesFile1; % 坐标1文件句柄
global gHandlesFile2; % 坐标2文件句柄
global gHandlesFile3; % 坐标3文件句柄
global gHandlesFile4; % 坐标4文件句柄
global gHandlesFile5; % 演示数据文件句柄

global gFFTFlag; % 判定主界面中是否勾选FFT选项
global gSaveDataFlag; % 保存已选数据标志

global gLeadStatus; % 导联线连接状态

if gLeadStatus == 1 % 导联线脱落
    set(handles.text_ls, 'string', '脱落', 'ForegroundColor',[1 0 0]);
else  % 导联线连接上
    set(handles.text_ls, 'string', '连接', 'ForegroundColor',[0 0 0]);
end

% 在坐标1上，绘制一次波形，并更新坐标范围
gHandlesPlot1 = plot(handles.axes1, gAxes1XLeft, gAxes1YLeft, 'b', gAxes1XRight, gAxes1YRight, 'b');
UpdateAxesRange(handles.axes1); % 更新坐标范围

% 在坐标2上，绘制一次波形，并更新坐标范围
gHandlesPlot2 = plot(handles.axes2, gAxes2XLeft, gAxes2YLeft, 'b', gAxes2XRight, gAxes2YRight, 'b');
UpdateAxesRange(handles.axes2); % 更新坐标范围    

% 在坐标3上，绘制一次波形，并更新坐标范围
gHandlesPlot3 = plot(handles.axes3, gAxes3XLeft, gAxes3YLeft, 'b', gAxes3XRight, gAxes3YRight, 'b');
UpdateAxesRange(handles.axes3); % 更新坐标范围

if gFFTFlag == 1 % 如果已勾选FFT选项
    gHandlesPlot4 = plot(handles.axes4, gAxes4X, gAxes4Y, 'b'); % 绘制幅度谱
    axis(handles.axes4, [0 10 0 1]); % 变换坐标，只显示0-10Hz        
elseif gFFTFlag == 0 % 如果未勾选FFT选项
    delete(gHandlesPlot4);
end

if gSaveDataFlag == 1
    if gSaveAxes1Flag == 1
        if isempty(gSaveAxes1Data) == 0 % 如果有数据需要保存
            fprintf(gHandlesFile1, '%.0f\n', gSaveAxes1Data(1 : end)); % 将数据保存到文件
            gSaveAxes1Data = []; % 清空变量
        end
    end
    if gSaveAxes2Flag == 1
        if isempty(gSaveAxes2Data) == 0 % 如果有数据需要保存
            fprintf(gHandlesFile2, '%.0f\n', gSaveAxes2Data(1 : end)); % 将数据保存到文件
            gSaveAxes2Data = []; % 清空变量
        end
    end    
    if gSaveAxes3Flag == 1
        if isempty(gSaveAxes3Data) == 0 % 如果有数据需要保存
            fprintf(gHandlesFile3, '%.0f\n', gSaveAxes3Data(1 : end)); % 将数据保存到文件
            gSaveAxes3Data = []; % 清空变量
        end
    end
    if gSaveAxes4Flag == 1
        if isempty(gSaveAxes4Data) == 0 % 如果有数据需要保存
            fprintf(gHandlesFile4, '%.0f\n', gSaveAxes4Data(1 : end)); % 将数据保存到文件
            gSaveAxes4Data = []; % 清空变量
        end
    end   
    if gSaveDemoFlag == 1
        if isempty(gSaveDemoData) == 0 % 如果有数据需要保存
            fprintf(gHandlesFile5, '%.0f\n', gSaveDemoData(1 : end)); % 将数据保存到文件
            gSaveDemoData = []; % 清空变量
        end
    end
end

function UpdateAxesRange(axesName)
% 更新坐标范围
%   输入参数axesName为坐标轴名称
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global MAX_X_CNT; % 串口开启标志，0-串口为关闭状态，1-串口为开启状态
global gYScale; % 纵坐标范围
global gYShift; % 调整垂直位置时对应的Y轴移位值
set(axesName, 'XLim', [1 MAX_X_CNT]); % 更新X轴范围
set(axesName, 'YLim', gYScale + gYShift); % 更新Y轴范围

function DemoDraw(~, ~, handles)
% 演示模式下绘制波形
%   输入参数handles
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

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

global gHandlesPlot1; % 坐标1的曲线句柄
global gHandlesPlot2; % 坐标2的曲线句柄
global gHandlesPlot3; % 坐标3的曲线句柄
global gHandlesPlot4; % 坐标4的曲线句柄

global gFFTFlag; % 判定主界面中是否勾选FFT选项

global gRdFinishFlag; % 用于演示模式，读取完成时置为1
global gCSVECGWave; % CSV文件读取到的心电波形数据

global gOriginalWave; % 从CSV文件读取的完整的心电波形数据
global gWaveLength; % 从CSV文件读取的完整的心电波形数据的长度
global gXCnt; % 计数器

if gRdFinishFlag == 0
    gXCnt = 1; % 初始值为1
    
    gOriginalWave = gCSVECGWave'; % 坐标1显示原始波形
    gWaveLength = length(gOriginalWave); % 计算从CSV文件读取的完整的心电波形数据的长度

    gRdFinishFlag = 1; % 将标志置为1，表示读取完成
end
    
DemoAnalyzeData(gOriginalWave(gXCnt)); % 处理原始数据
    
if gXCnt >= gWaveLength
    gXCnt = 1; % 计数器计数到最后一个数据，则复位到第一个数据位置
else
    gXCnt = gXCnt + 1; % 递增
end   
    
if mod(gXCnt, 10) == 0
    % 在坐标1上，绘制一次波形，并更新坐标范围
    gHandlesPlot1 = plot(handles.axes1, gAxes1XLeft, gAxes1YLeft, 'b', gAxes1XRight, gAxes1YRight, 'b');
    UpdateAxesRange(handles.axes1); % 更新坐标范围

    % 在坐标2上，绘制一次波形，并更新坐标范围
    gHandlesPlot2 = plot(handles.axes2, gAxes2XLeft, gAxes2YLeft, 'b', gAxes2XRight, gAxes2YRight, 'b');
    UpdateAxesRange(handles.axes2); % 更新坐标范围    

    % 在坐标3上，绘制一次波形，并更新坐标范围
    gHandlesPlot3 = plot(handles.axes3, gAxes3XLeft, gAxes3YLeft, 'b', gAxes3XRight, gAxes3YRight, 'b');
    UpdateAxesRange(handles.axes3); % 更新坐标范围    

    if gFFTFlag == 1 % 如果已勾选FFT选项
        gHandlesPlot4 = plot(handles.axes4, gAxes4X, gAxes4Y, 'b'); % 绘制幅度谱
        axis(handles.axes4, [0 10 0 1]); % 变换坐标，只显示0-10Hz        
    elseif gFFTFlag == 0 % 如果未勾选FFT选项
        delete(gHandlesPlot4);
    end  
end
% drawnow; % 刷新屏幕

function OperateFile(openFlag)
% 操作文件，执行文件的创建/打开和关闭
%   输入参数openFlag为创建/打开或关闭标志，1-创建/打开，0-关闭
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gSavePathName; % 数据存储文件路径
global moduleInfo; % 模块信息

global gHandlesFile1; % 坐标1文件句柄
global gHandlesFile2; % 坐标2文件句柄
global gHandlesFile3; % 坐标3文件句柄
global gHandlesFile4; % 坐标4文件句柄
global gHandlesFile5; % 演示数据文件句柄

global gSaveDataFlag;  % 保存已选数据标志
global gSaveAxes1Flag; % 保存坐标1数据标志
global gSaveAxes2Flag; % 保存坐标2数据标志
global gSaveAxes3Flag; % 保存坐标3数据标志
global gSaveAxes4Flag; % 保存坐标4数据标志
global gSaveDemoFlag;  % 保存演示数据标志

global gSaveAxes1Data; % 保存坐标1数据变量
global gSaveAxes2Data; % 保存坐标2数据变量
global gSaveAxes3Data; % 保存坐标3数据变量
global gSaveAxes4Data; % 保存坐标4数据变量
global gSaveDemoData;  % 保存演示数据变量

timeForm = 'yyyy.mm.dd HH-MM-SS'; % 时间格式
saveTime = datestr(now, timeForm); % 将日期和时间转换为字符串格式
disp('call OperateFile');

if openFlag == 1 % 创建文件
    if gSaveDataFlag == 1
        if gSaveAxes1Flag == 1
            fileName = strcat('坐标1-', saveTime); % 文件名坐标信息+日期时间
            fileName = strcat(fileName, '.csv'); % 增加文件后缀
            fileName = strcat(moduleInfo, fileName); % 文件名格式为“xx模块坐标x+yyyy.mm.dd HH-MM-SS.csv”
            filePath = [gSavePathName fileName]; % 文件路径+文件名
            gHandlesFile1 = fopen(filePath, 'a'); % 创建/打开一个文件
        end
        if gSaveAxes2Flag == 1
            fileName = strcat('坐标2-', saveTime); % 文件名坐标信息+日期时间
            fileName = strcat(fileName, '.csv'); % 增加文件后缀
            fileName = strcat(moduleInfo, fileName); % 文件名格式为“xx模块坐标x+yyyy.mm.dd HH-MM-SS.csv”
            filePath = [gSavePathName fileName]; % 文件路径+文件名
            gHandlesFile2 = fopen(filePath, 'a'); % 创建/打开一个文件
        end
        if gSaveAxes3Flag == 1
            fileName = strcat('坐标3-', saveTime); % 文件名坐标信息+日期时间
            fileName = strcat(fileName, '.csv'); % 增加文件后缀
            fileName = strcat(moduleInfo, fileName); % 文件名格式为“xx模块坐标x+yyyy.mm.dd HH-MM-SS.csv”
            filePath = [gSavePathName fileName]; % 文件路径+文件名
            gHandlesFile3 = fopen(filePath, 'a'); % 创建/打开一个文件
        end
        if gSaveAxes4Flag == 1
            fileName = strcat('坐标4-', saveTime); % 文件名坐标信息+日期时间
            fileName = strcat(fileName, '.csv'); % 增加文件后缀
            fileName = strcat(moduleInfo, fileName); % 文件名格式为“xx模块坐标x+yyyy.mm.dd HH-MM-SS.csv”
            filePath = [gSavePathName fileName]; % 文件路径+文件名
            gHandlesFile4 = fopen(filePath, 'a'); % 创建/打开一个文件
        end
        if gSaveDemoFlag == 1
            fileName = strcat('演示数据-', saveTime); % 文件名坐标信息+日期时间
            fileName = strcat(fileName, '.csv'); % 增加文件后缀
            fileName = strcat(moduleInfo, fileName); % 文件名格式为“xx模块坐标x+yyyy.mm.dd HH-MM-SS.csv”
            filePath = [gSavePathName fileName]; % 文件路径+文件名
            gHandlesFile5 = fopen(filePath, 'a'); % 创建/打开一个文件
        end        
    end
else % 关闭文件
    if gSaveDataFlag == 1
        if gSaveAxes1Flag == 1
            fclose(gHandlesFile1); % 关闭坐标1对应的文件
            gSaveAxes1Data = []; % 清空变量
        end
        if gSaveAxes2Flag == 1
            fclose(gHandlesFile2); % 关闭坐标2对应的文件
            gSaveAxes2Data = []; % 清空变量
        end
        if gSaveAxes3Flag == 1
            fclose(gHandlesFile3); % 关闭坐标3对应的文件
            gSaveAxes3Data = []; % 清空变量
        end
        if gSaveAxes4Flag == 1
            fclose(gHandlesFile4); % 关闭坐标4对应的文件
            gSaveAxes4Data = []; % 清空变量
        end
        if gSaveDemoFlag == 1
            fclose(gHandlesFile5); % 关闭演示数据对应的文件
            gSaveDemoData = []; % 清空变量
        end
    end
end

% --- Executes during object deletion, before destroying properties.
function figure1_DeleteFcn(hObject, eventdata, handles)
ReleaseAll();  % 释放资源
clear global;  % 退出时，清空全局变量
delete(hObject); % 关闭窗口

function ReleaseAll()
% 释放资源，删除定时器对象和串口对象，关闭正在保存的文件等
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gRealTimer; % 串口数据实时绘制定时器
disp('call ReleaseAll');
% 删除定时器
t = timerfind; % 查找定时器对象
if ~isempty(t)  % 如果查找到定时器对象
    switch get(gRealTimer, 'Running')
        case 'on'
            stop(gRealTimer); % 关闭实时模式定时器
            %正在画图时，关闭则需要保存的文件
            OperateFile(0); 
    end
    stop(t); % 关闭定时器
    delete(t); % 删除定时器对象
end

% 删除串口
scoms = instrfind; % 查找串口对象
try
    stopasync(scoms); % 停止异步读写操作
    fclose(scoms); % 关闭串口
    delete(scoms); % 从内存清除串口对象
catch
    disp('serial operate error');
end 

% --- Executes during object creation, after setting all properties.
function pushbutton_sample_CreateFcn(hObject, eventdata, handles)
% hObject    handle to pushbutton_sample (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

