function varargout = ReadData(varargin)
% DATAREAD MATLAB code for ReadData.fig
%      DATAREAD, by itself, creates a new DATAREAD or raises the existing
%      singleton*.
%
%      H = DATAREAD returns the handle to a new DATAREAD or the handle to
%      the existing singleton*.
%
%      DATAREAD('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DATAREAD.M with the given input arguments.
%
%      DATAREAD('Property','Value',...) creates a new DATAREAD or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before ReadData_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to ReadData_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help ReadData

% Last Modified by GUIDE v2.5 18-Mar-2020 09:18:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ReadData_OpeningFcn, ...
                   'gui_OutputFcn',  @ReadData_OutputFcn, ...
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

% --- Executes just before ReadData is made visible.
function ReadData_OpeningFcn(hObject, eventdata, handles, varargin)
% Choose default command line output for ReadData
handles.output = hObject;

set(gcf, 'numbertitle', 'off', 'name', '数据演示'); % 设置当前窗口名字
movegui(gcf, 'center'); % 将窗口置于屏幕中间

global gFilePath;  %选择打开文件的路径名
if ~isempty(gFilePath)
    set(handles.edit_filepath,'String',gFilePath);
else
    gFilePath = '.\RecData\';
    set(handles.edit_filepath,'String','.\RecData\')
end

if exist('RecData','dir') == 0    % 判断当前目录中文件夹是否存在
    mkdir('RecData');   % 创建文件夹
end

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes ReadData wait for user response (see UIRESUME)
% uiwait(handles.figure1);

% --- Outputs from this function are returned to the command line.
function varargout = ReadData_OutputFcn(hObject, eventdata, handles) 
% Get default command line output from handles structure
varargout{1} = handles.output;

function edit_filepath_Callback(hObject, eventdata, handles)

% --- Executes during object creation, after setting all properties.
function edit_filepath_CreateFcn(hObject, eventdata, handles)
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in pushbutton_open.
function pushbutton_open_Callback(hObject, eventdata, handles)
global gFilePath;  %选择打开文件的路径名
[fileName, pathName] = uigetfile('*.csv','Pick a file','.\RecData'); % 获取文件名和文件路径
filePath = [pathName, fileName]; % 将文件路径和文件名拼接之后赋值给fileTmp
if length(filePath) > 2 % 路径和文件名最短为2个字符，比如“C:”
    gFilePath = filePath;
    set(handles.edit_filepath, 'String', gFilePath);
end

% --- Executes on button press in pushbutton_ok.
function pushbutton_ok_Callback(hObject, eventdata, handles)
ReadFile(); % 打开文件，读取数据


function ReadFile()
% 打开文件读取心电原始数据
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gHandlesMFig; % 定义用于存放主窗体句柄的全局变量
global gCSVECGWave; % CSV文件读取到的心电波形数据
global gDemoFlag; % 串口模式和演示模式标志，0-串口模式，1-演示模式
global gFilePath;
if ~isempty(gFilePath)    % 路径不为空
    set(gHandlesMFig.pushbutton_sample, 'String', '开始演示', 'Enable', 'on');
    try
        gCSVECGWave = csvread(gFilePath); % CSV文件读取心电波形数据
        gDemoFlag = 1; % 演示模式
        close;
    catch
        close;
        disp('读取数据失败');
        gDemoFlag = 0; % 读取失败，则继续将其设置为默认的串口模式
        set(gHandlesMFig.pushbutton_sample, 'String', '开始采样', 'Enable', 'on');   % 切换到串口模式
        helpdlg('读取数据失败', '提示');
    end
end

% --- Executes on button press in pushbutton_cancel.
function pushbutton_cancel_Callback(hObject, eventdata, handles)
close;

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% global gClosedFigFlag; % 弹出的窗口关闭标志，0-未关闭，1-已关闭
% gClosedFigFlag = 1; % 将窗口关闭标志置为1
delete(hObject);
