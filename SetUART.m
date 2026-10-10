function varargout = SetUART(varargin)
% SETUART MATLAB code for SetUART.fig
%      SETUART, by itself, creates a new SETUART or raises the existing
%      singleton*.
%
%      H = SETUART returns the handle to a new SETUART or the handle to
%      the existing singleton*.
%
%      SETUART('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in SETUART.M with the given input arguments.
%
%      SETUART('Property','Value',...) creates a new SETUART or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before SetUART_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to SetUART_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help SetUART

% Last Modified by GUIDE v2.5 18-Mar-2020 08:47:28

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @SetUART_OpeningFcn, ...
                   'gui_OutputFcn',  @SetUART_OutputFcn, ...
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

% --- Executes just before SetUART is made visible.
function SetUART_OpeningFcn(hObject, eventdata, handles, varargin)
% Choose default command line output for SetUART
handles.output = hObject;

global gSerial; % 串口对象

set(gcf, 'numbertitle', 'off', 'name', '串口设置'); % 窗口名
movegui(gcf,'center'); % 将窗口置于屏幕中间

% 设置当前窗口各个控件的参数
set(handles.popupmenu_baud_rate, 'string', {'4800', '9600', '14400', '19200', '38400',...
    '57600', '76800', '115200'}, 'value', 8); % 波特率
set(handles.popupmenu_data_bits, 'string', {'8', '9'}); % 数据位
set(handles.popupmenu_stop_bits, 'string', {'1', '1.5', '2'}); % 停止位
set(handles.popupmenu_parity, 'string', {'NONE', 'ODD', 'EVEN'}); % 校验位

ScanUART(handles); % 扫描串口

global gUARTOpenFlag; % 串口开启标志，0-串口为关闭状态，1-串口为开启状态
axes(handles.axes_img);
if gUARTOpenFlag == 1
    set(handles.pushbutton_open_serial, 'String', '关闭串口');
    A=imread('.\Res\open.png');
    imshow(A);      % 显示图片
else
    set(handles.pushbutton_open_serial, 'String', '打开串口');
    A=imread('.\Res\close.png');
    imshow(A);      % 显示图片
end

% Update handles structure
guidata(hObject, handles);
% UIWAIT makes SetUART wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = SetUART_OutputFcn(hObject, eventdata, handles) 
% Get default command line output from handles structure
varargout{1} = handles.output;

% --- Executes on selection change in popupmenu_port_num.
function popupmenu_port_num_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function popupmenu_port_num_CreateFcn(hObject, eventdata, handles)
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in popupmenu_baud_rate.
function popupmenu_baud_rate_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function popupmenu_baud_rate_CreateFcn(hObject, eventdata, handles)
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in popupmenu_data_bits.
function popupmenu_data_bits_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function popupmenu_data_bits_CreateFcn(hObject, eventdata, handles)
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in popupmenu_stop_bits.
function popupmenu_stop_bits_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function popupmenu_stop_bits_CreateFcn(hObject, eventdata, handles)
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on selection change in popupmenu_parity.
function popupmenu_parity_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function popupmenu_parity_CreateFcn(hObject, eventdata, handles)
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in pushbutton_open_serial.
function pushbutton_open_serial_Callback(hObject, eventdata, handles)
global gSerial; % 串口对象
global gUARTOpenFlag; % 串口开启标志，0-串口为关闭状态，1-串口为开启状态

global gStartIndex; % 串口中断产生时，接收到的全部数据中，第一个模块ID的索引
gStartIndex = 0; % 将该值赋值为0，表示尚未标定第一个模块ID的索引

global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式
global gHandlesMFig; % 主窗口句柄

global gRealTimer; % 串口数据实时绘制定时器

if gUARTOpenFlag == 1 % 如果单击按钮之前串口为开启状态
    gUARTOpenFlag = 0; % 将串口状态设置为关闭
    set(gHandlesMFig.pushbutton_sample,'String','开始采样'); % 设置主界面开始采样按扭
    switch get(gRealTimer, 'Running')
        case 'on'
            stop(gRealTimer); % 停止画图定时器
    end

    scoms = instrfind; % 查找串口对象
    try
        stopasync(scoms); % 停止异步读写操作
        fclose(scoms); % 关闭串口
        uartstr = strcat('串口状态：','关闭');  %左下角显示串口状态信息
        set(gHandlesMFig.text_uartinfo,'String',uartstr);
        % delete(scoms); % 从内存清除串口对象
    catch
        disp('serial operate error');
    end     
else % 如果单击按钮之前串口为关闭状态
%     scoms = instrfind; % 查找串口对象
%     try
%         stopasync(scoms); % 停止异步读写操作
%         fclose(scoms); % 关闭串口
%         delete(scoms); % 从内存清除串口对象
%     catch
%         disp('serial operate error');
%     end         
        
    num = get(handles.popupmenu_port_num, 'value'); % 获取所选项的序号 
    cellArr = get(handles.popupmenu_port_num, 'string'); % 获取所有选项组成的元胞数组
    cellArrPortNum = cellArr(num); % 根据所选项的序号，获取所选串口号的字符串元胞数组

    num = get(handles.popupmenu_baud_rate, 'value'); % 获取所选项的序号
    cellArr = get(handles.popupmenu_baud_rate, 'string'); % 获取所有选项组成的元胞数组
    cellArrBaudRate = cellArr(num); % 根据所选项的序号，获取所选波特率的字符串元胞数组

    num = get(handles.popupmenu_data_bits, 'value'); % 获取所选项的序号
    cellArr = get(handles.popupmenu_data_bits, 'string'); % 获取所有选项组成的元胞数组
    cellArrDataBits = cellArr(num); % 根据所选项的序号，获取所选数据位的字符串元胞数组

    num = get(handles.popupmenu_stop_bits, 'value'); % 获取所选项的序号
    cellArr = get(handles.popupmenu_stop_bits, 'string'); % 获取所有选项组成的元胞数组
    cellArrStopBits = cellArr(num); % 根据所选项的序号，获取所选停止位字符串元胞数组

    num = get(handles.popupmenu_parity, 'value'); % 获取所选项的序号
    cellArr = get(handles.popupmenu_parity, 'string'); % 获取所有选项组成的元胞数组
    cellArrParity = cellArr(num); % 根据所选项的序号，获取所选校验位的字符串元胞数组

    strPortNum = cellArrPortNum{1}; % 获取所选串口号字符串      
    dBaudRate = str2double(cellArrBaudRate); % 将字符串转换为双精度的波特率        
    dDataBits = str2double(cellArrDataBits); % 将字符串转换为双精度的数据位
    dStopBits = str2double(cellArrStopBits); % 将字符串转换为双精度的停止位
    strParity = cellArrParity{1}; % 获取所选校验和字符串
        
    %串口配置，serial函数
    gSerial = serial(strPortNum, 'BaudRate', dBaudRate, 'DataBits', dDataBits, ...
        'StopBits', dStopBits, 'Parity', strParity, ...
        'InputBufferSize', 1024, 'OutputBufferSize', 1024, 'Timeout', 0.1, ...        
        'BytesAvailableFcnCount', 200, 'BytesAvailableFcnMode', 'byte', ...
        'BytesAvailableFcn', {@ProcRecData,handles});   
   
    gDemoFlag = 0; % 串口模式 
    gUARTOpenFlag = 1; % 将串口打开标志置为已打开 
    set(gHandlesMFig.pushbutton_sample, 'String', '开始采样'); % 设置主界面开始采样按扭
end
close; % 关闭串口设置窗口

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
global gClosedFigFlag; % 弹出的窗口关闭标志，0-未关闭，1-已关闭
disp('call figure1_CloseRequestFcn');
gClosedFigFlag = 1; % 将窗口关闭标志置为1
delete(hObject);
