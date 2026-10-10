function ScanUART(handles)
% 扫描串口
%   输入参数handles，GUI界面的句柄
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

coms = 0; % 初始化
key = 'HKEY_LOCAL_MACHINE\HARDWARE\DEVICEMAP\SERIALCOMM'; % 串口注册表地址
[~, str] = dos(['REG QUERY ' key]); % 获取到全部串口信息列表（字符串形式）     
 
% 将全部串口信息列表中空格隔开的字符串以字符串数组的形式保存于元胞数组arrStr
arrStr = strread(str, '%s', 'delimiter', ' ');
for i = 1 : numel(arrStr)                       
    if strcmp(arrStr{i}(1 : 3), 'COM') % 在数组中，查找COM前缀
         if ~iscell(coms)
             coms = arrStr(i);
         else
             coms{end + 1} = arrStr{i};
         end
    end
end
% 显示在界面的串口号下拉框中
set(handles.popupmenu_port_num, 'value', length(coms), 'string', coms);