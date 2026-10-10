function cfg = ecg_config()
%ECG_CONFIG 监护型心电处理系统 —— 物理量与算法指标的唯一定义处
%   工程准则：凡与"真实世界"耦合的数字（采样率/量程/指标/阈值/打印节流）
%   只允许出现在本文件。算法模块里再出现硬编码数字，就是移植期的定时炸弹。
%   移植到 C 时本文件等价于一个 ecg_config.h（宏 + 一个 const 配置结构体）。
%
%   对应硬件：
%     前端  = 自建心电模拟板（TL062 仪放 + LMV358 有源滤波 + LMV324 导联判决，
%             Uref = 1.65V 中点偏置，输出 ECG / LEAD_OFF / RA / LA 为模拟量，
%             板载电荷泵产生 -5V 供 TL062 使用；板上无 ADC、无 MCU、无 USB 串口）
%     MCU   = 立创·天空星 STM32F407VET6（Cortex-M4F @168MHz，单精度硬件 FPU）
%
%   标注 [实测] 的字段是占位值，必须由你测量原理图后回填，否则误差折算不成立。

%% ================= 采样与硬件（M1/M3）=================
cfg.Fs = 500;                       % 采样率 SPS，由 TIM2 TRGO 精确触发
cfg.T  = 1 / cfg.Fs;                % 2 ms/样本 → 168MHz 下 336000 cycle 预算

cfg.adc.bits        = 12;
cfg.adc.full        = 2^cfg.adc.bits - 1;                       % 4095
cfg.adc.vref        = 3.3;                                     % [实测] VREF+ 必须与 VDDA 同源
cfg.adc.vbias       = 1.65;                                    % 原理图 Uref / TP9
cfg.adc.biasCode    = round(cfg.adc.vbias/cfg.adc.vref*cfg.adc.full);  % ≈2048
cfg.adc.uvPerLsbRaw = cfg.adc.vref / cfg.adc.full * 1e6;        % 引脚端 ≈806 µV/LSB
cfg.adc.gainFe      = 100;                                     % [实测] 前端总增益 V/V
cfg.adc.uvPerLsb    = cfg.adc.uvPerLsbRaw / cfg.adc.gainFe;     % 电极端 µV/LSB

%% ================= 滤波指标（监护型 0.5–40Hz）（M5）=================
cfg.filt.biasEn    = true;    % 先扣 1.65V 直流（整数相减，零相位、零代价）
cfg.filt.hpEn      = false;   % 数字高通：原理图疑已含 ~0.3–1Hz 模拟高通 → 默认关，实测再定
cfg.filt.fHp       = 0.5;     % Hz，hpEn=true 时生效
cfg.filt.notchEn   = true;
cfg.filt.fNotch    = 50;      % Hz 工频
cfg.filt.notchBeta = 0.96;    % 极点半径 → 3dB 缺口宽 ≈ 3.3*(1-beta)*Fs/pi ≈ 21.0 Hz
cfg.filt.fPass     = 40;      % Hz 通带上限（监护型）
cfg.filt.fStop     = 47;      % Hz 阻带起点：必须 ≤49Hz，否则电网 ±1Hz 偏差漏进通带
cfg.filt.astDb     = 80;      % dB FIR 阻带衰减
cfg.filt.useSingle = true;    % true=用 single 仿真 M4F 硬件浮点；false=double，与 MATLAB 对拍用

%% ================= 心率与统计窗（M6/M7）=================
cfg.hr.winLen     = 2048;   % 自适应阈值统计窗 = 4.096 s（对应原工程 MAX_X_CNT）
cfg.hr.rrMin      = 250;    % 不应期 0.5 s（= 原工程 findpeaks 的 MinPeakDistance）
cfg.hr.peakMargin = 200;   % 阈值 = 窗内最大值 - 此值 [实测] 必须按"滤波后"幅值重标
cfg.hr.absMin     = 150;    % 窗内摆幅小于此值 → 判信号丢失，不输出心率
cfg.hr.maxRR      = 8;      % 参与中值的最近 RR 个数（一个 4.1s 窗最多 5~7 个）
cfg.hr.hrMin      = 30;     % bpm 合法下限（原工程用 0，监护场景太松）
cfg.hr.hrMax      = 250;    % bpm 合法上限（原工程用 300）

cfg.det.blkLen      = 64;   % 滑动窗最大值分块长度：2048/64 = 32 块
cfg.det.confirmFall = 3;    % 连续 N 样本不创新高 → 确认 R 峰（代价：N*2ms 判决延迟）

%% ================= 异常判据（M7/M9）=================
cfg.lo.thrCode     = 3600;  % [实测] LEAD_OFF 通道码值高于此 = 导联脱落
cfg.lo.debounce     = 50;   % 连续 50 样本(100ms)成立才切状态，防抖
cfg.stuck.repeat    = 50;   % 连续 50 个完全相同码值 → 采样链路冻结（模拟侧的"缺包等价物"）

%% ================= 调试输出节流（M8）=================
cfg.dbg.sampleDiv  = 5;      % 每 5 样本打一行样本级日志 → 100 行/s
cfg.dbg.summaryDiv = 250;    % 每 250 样本(0.5s) 打一行摘要
cfg.dbg.uartBaud   = 115200; % 用于反算打印带宽占用是否吃满串口

%% ================= 仿真激励 =================
% 直接借用数字模块采出的 CSV：它本身就是 12bit、0~4095、中点约 2048 的 ADC 码流，
% 与你"模拟前端 + F407 ADC"将得到的码流同构，可作为等价激励。
cfg.sim.filePat   = fullfile('..', 'RecData', '*.csv');
cfg.sim.n         = 6000;   % 仿真样本数（12 s）
cfg.sim.leadOffAt = 4000;   % 在此样本处人工注入"导联脱落"（0=不注入）
cfg.sim.stuckAt   = 0;      % 在此样本处人工注入"码值冻结"（0=不注入）
end
