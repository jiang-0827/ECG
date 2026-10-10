function varargout = SaveData(varargin)
% DATASAVE MATLAB code for SaveData.fig
%      DATASAVE, by itself, creates a new DATASAVE or raises the existing
%      singleton*.
%
%      H = DATASAVE returns the handle to a new DATASAVE or the handle to
%      the existing singleton*.
%
%      DATASAVE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in DATASAVE.M with the given input arguments.
%
%      DATASAVE('Property','Value',...) creates a new DATASAVE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before SaveData_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to SaveData_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help SaveData

% Last Modified by GUIDE v2.5 24-Mar-2020 10:49:44

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @SaveData_OpeningFcn, ...
                   'gui_OutputFcn',  @SaveData_OutputFcn, ...
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


% --- Executes just before SaveData is made visible.
function SaveData_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to SaveData (see VARARGIN)

% Choose default command line output for SaveData
handles.output = hObject;

set(gcf, 'numbertitle', 'off', 'name', '数据存储'); % 设置当前窗口名字
movegui(gcf, 'center'); % 将窗口置于屏幕中间

global gSavePathName;  % 保存路径名
global gSaveAxes1Flag; % 保存坐标1数据标志
global gSaveAxes2Flag; % 保存坐标2数据标志
global gSaveAxes3Flag; % 保存坐标3数据标志
global gSaveAxes4Flag; % 保存坐标4数据标志
global gSaveDemoFlag;  % 保存演示数据标志

if ~isempty(gSavePathName)
    set(handles.edit_filepath,'String',gSavePathName);
else
    set(handles.edit_filepath,'String',strcat(pwd,'\RecData\'));
end

if gSaveAxes1Flag == 1
    set(handles.checkbox_axes1,'value',1);
else
    set(handles.checkbox_axes1,'value',0);
end

if gSaveAxes2Flag == 1
    set(handles.checkbox_axes2,'value',1);
else
    set(handles.checkbox_axes2,'value',0);
end

if gSaveAxes3Flag == 1
    set(handles.checkbox_axes3,'value',1);
else
    set(handles.checkbox_axes3,'value',0);
end

if gSaveAxes4Flag == 1
    set(handles.checkbox_axes4,'value',1);
else
    set(handles.checkbox_axes4,'value',0);
end

if gSaveDemoFlag == 1
    set(handles.checkbox_demo,'value',1);
else
    set(handles.checkbox_demo,'value',0);
end

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes SaveData wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = SaveData_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in pushbutton_ok.
function pushbutton_ok_Callback(hObject, eventdata, handles)
global moduleInfo; % 模块信息
global gSaveDataFlag; % 保存已选数据标志
global gSavePathName;
gSavePathName = get(handles.edit_filepath, 'String'); % 获取路径和文件名
disp(gSavePathName);
moduleInfo = '心电0x30';
gSaveDataFlag = 1;
close;


% --- Executes on button press in pushbutton_cancel.
function pushbutton_cancel_Callback(hObject, eventdata, handles)
close;


% --- Executes on button press in checkbox_axes1.
function checkbox_axes1_Callback(hObject, eventdata, handles)
global gSaveAxes1Flag; % 保存坐标1数据标志
if get(handles.checkbox_axes1, 'value') == 1
    gSaveAxes1Flag = 1;
else
    gSaveAxes1Flag = 0;
end


% --- Executes on button press in checkbox_axes2.
function checkbox_axes2_Callback(hObject, eventdata, handles)
global gSaveAxes2Flag; % 保存坐标2数据标志
if get(handles.checkbox_axes2, 'value') == 1
    gSaveAxes2Flag = 1;
else
    gSaveAxes2Flag = 0;
end


% --- Executes on button press in checkbox_axes3.
function checkbox_axes3_Callback(hObject, eventdata, handles)
global gSaveAxes3Flag; % 保存坐标3数据标志
if get(handles.checkbox_axes3, 'value') == 1
    gSaveAxes3Flag = 1;
else
    gSaveAxes3Flag = 0;
end


% --- Executes on button press in checkbox_axes4.
function checkbox_axes4_Callback(hObject, eventdata, handles)
global gSaveAxes4Flag; % 保存坐标4数据标志
if get(handles.checkbox_axes4, 'value') == 1
    gSaveAxes4Flag = 1;
else
    gSaveAxes4Flag = 0;
end


% --- Executes on button press in checkbox_demo.
function checkbox_demo_Callback(hObject, eventdata, handles)
global gSaveDemoFlag; % 保存演示数据标志
if get(handles.checkbox_demo, 'value') == 1
    gSaveDemoFlag = 1;
else
    gSaveDemoFlag = 0;
end


function edit_filepath_Callback(hObject, eventdata, handles)
% hObject    handle to edit_filepath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_filepath as text
%        str2double(get(hObject,'String')) returns contents of edit_filepath as a double


% --- Executes during object creation, after setting all properties.
function edit_filepath_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_filepath (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton_open.
function pushbutton_open_Callback(hObject, eventdata, handles)
path = uigetdir; % 打开当前目录的路径
file_path = [path '\'];
if length(file_path) > 5 % 显示选择路径
    set(handles.edit_filepath, 'String', file_path);
end
