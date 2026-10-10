function SendCmd(cmd)
% 连续向串口发送命令，确保向从机发送命令成功
%   输入参数cmd为向串口发送的命令，遵照PCT协议，一个命令包由10个字节组成
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gSerial; % 串口对象
fwrite(gSerial, cmd, 'uint8', 'sync');
fwrite(gSerial, cmd, 'uint8', 'sync');