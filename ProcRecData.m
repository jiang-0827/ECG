function ProcRecData(hObject, ~, handles)
% 处理串口接收到的数据
%   输入参数hObject, handles
%   COPYRIGHT 2018-2020 LEYUTEK. All rights reserved.

global gSerial; % 串口对象
global gStartIndex; % 串口中断产生时，接收到的全部数据中，第一个模块ID的索引
global gRecAllData; % 串口中断产生时，接收到的全部数据 
global gRecPartData; % 从串口接收到的所有数据中取出第一个模块ID开始到最后的所有数据
global gStartFlag; % 开始采样或开始演示标志，0-停止采样或停止演示，1-开始采样或开始演示

% 串口打开时，读取200个数据，否则，退出回调函数
switch get(gSerial, 'Status')
    case 'open'
        gRecAllData = fread(gSerial, 200);
    case 'closed'
        return;
end

if gStartFlag == 1
    % 处理第一次中断时的串口数据，并标记
    if ~gStartIndex
        for iCnt = 1 : 200
            if gRecAllData(iCnt) == 48 || gRecAllData(iCnt) == 49 || ...
                    gRecAllData(iCnt) == 50 || gRecAllData(iCnt) == 51 || ...
                    gRecAllData(iCnt) == 52 % 匹配模块ID
                gStartIndex = iCnt; % 如果检测到为模块ID则赋值
                gRecPartData = gRecAllData(gStartIndex : 200); % 取二级ID之后的数据
                return;
            end
        end
        if gStartIndex == 0
            return; % 前200个数据都找不到模块ID,一般在不同工程切换时
        end
    end
    
    % alignSeq为完整的数据包序列，第一个数据为模块ID
    if gStartIndex == 1
        alignSeq = gRecPartData; % 如果第一个数据即为模块ID，则将接收到的数据直接赋值给alignSeq
        gRecPartData = gRecAllData; % 接收到的数据全部赋值给recPartData，下次再赋值给alignSeq
    elseif gStartIndex ~= 0
        alignSeq = [gRecPartData ; gRecAllData(1 : gStartIndex - 1)]; % recPartData为上次剩余的数据
        gRecPartData = gRecAllData(gStartIndex : 200); % 剩余的数据赋值给recPartData，下次再赋值给alignSeq
    end
    
    % 按照模块ID的索引循环
    for modIDIndex = 1 : 10 : (length(alignSeq) - 9)
        pctPack = alignSeq(modIDIndex : (modIDIndex + 9)); % 提取一个数据包（10个字节），赋值给pctPack
        
        if pctPack(1) >= 128
            gStartIndex = 0; % 如果收到的数据包中有错误，顺序变了，可以通过startIndex重新来过，但是这200个数据中剩余的数据如何处理？
            continue;
        end
        
        [errFlag, unpackRslt] = Unpack(pctPack); % 对数据进行解包
        
        if errFlag == 0 % 如果errFlag为0，表示解包结果正确
            RealAnalyzeData(unpackRslt); % 对解包结果进行数据处理
        end
    end
end
