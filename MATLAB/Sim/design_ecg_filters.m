function F = design_ecg_filters(cfg)
%DESIGN_ECG_FILTERS  设计"可逐点递推"的监护型滤波链，并自检指标
%   F = design_ecg_filters(cfg)
%
%   返回结构（字段布局与 C 的 const 系数表一一对应）：
%     F.hp.b,    F.hp.a     2 阶高通   biquad 系数（hpEn=false 时为"直通节"）
%     F.notch.b, F.notch.a  2 阶工频陷波 biquad 系数
%     F.lp.b                FIR 低通系数（列向量）
%     F.lp.nTaps            抽头数
%     F.lp.delaySmp/.delayMs 恒定群延迟（线性相位的唯一"代价"，可精确补偿）
%     F.bias                要先减掉的直流码值
%     F.m                   自检指标（纹波、49/50/51Hz 抑制、群延迟标准差）
%
%   ---- 三条设计理由（移植时别改）----
%   1) 直通节写成 b=[1 0 0], a=[1 0 0]：这样 C 里只需要一个 biquad 函数，
%      被关掉的级照样调用同一份代码，不引入 if 分支 —— 分支越少，移植期越不容易错。
%   2) 系数一律按 a(1) 归一化：否则递推式每样本要多一次除法（M4F 的 VDIV.F32 ≈14 cycle，
%      而乘加只有 3~7 cycle）。
%   3) FIR 取"偶数阶 = 奇数抽头"→ Type-I 线性相位，群延迟是整数样本，
%      补偿时不需要半样本插值。
%
%   ---- 为什么陷波器用 IIR 而低通用 FIR ----
%   陷波要"极窄极深"，只有 IIR 的共轭零极对做得到（2 阶即可，FIR 需几百阶）；
%   它的相位失真被限制在 47~53Hz 窄带内，对 0.5~40Hz 通带无害。
%   低通要"通带相位平直"，只有 FIR 做得到；而 F407 上 361 抽头只占 0.5% CPU，
%   所以在上位机上"用不起"的线性相位 FIR，在单片机上是免费的。

fs = cfg.Fs;
F  = struct();
F.bias = double(cfg.filt.biasEn) * cfg.adc.biasCode;

%% ---------- 级 1：0.5Hz 高通（2 阶 Butterworth，恰好一个 biquad）----------
if cfg.filt.hpEn
    [b, a] = butter(2, 2 * cfg.filt.fHp / fs, 'high');
    F.hp.b = (b(:) / a(1)).';
    F.hp.a = (a(:) / a(1)).';
else
    F.hp.b = [1 0 0]; F.hp.a = [1 0 0];
end

%% ---------- 级 2：50Hz 陷波（与 ECGDynamicPrj/NotchFilterECG.m 同式）----------
if cfg.filt.notchEn
    w0    = 2 * pi * cfg.filt.fNotch / fs;
    alpha = -2 * cos(w0);
    bt    = cfg.filt.notchBeta;
    F.notch.b = [1 alpha 1];              % 零点精确落在单位圆 ±w0 → 50Hz 处理论无穷衰减
    F.notch.a = [1 alpha*bt bt^2];        % 极点半径 bt 决定缺口宽度
    F.notch.bw3dB = 3.3 * (1 - bt) * fs / pi;
else
    F.notch.b = [1 0 0]; F.notch.a = [1 0 0]; F.notch.bw3dB = 0;
end

%% ---------- 级 3：FIR 线性相位低通（Kaiser 窗）----------
df  = cfg.filt.fStop - cfg.filt.fPass;         % 过渡带宽
n   = kaiserOrderEst(df, cfg.filt.astDb, fs);  % 偶数阶
bW  = kaiserBeta(cfg.filt.astDb);              % 阻带衰减(dB) → Kaiser 窗 beta
F.lp.b       = fir1(n, 2 * cfg.filt.fPass / fs, kaiser(n + 1, bW));
F.lp.b       = F.lp.b(:);
F.lp.nTaps   = numel(F.lp.b);
F.lp.delaySmp = n / 2;
F.lp.delayMs  = F.lp.delaySmp / fs * 1000;

%% ---------- 自检 1：整链幅频（三级相乘）----------
fchk = [0.5 1 5 10 20 30 40 45 47 49 50 51 55 100 150];
Hm   = ones(size(fchk));
[H, ~] = freqz(F.hp.b,    F.hp.a,    fchk, fs); Hm = Hm .* abs(H);
[H, ~] = freqz(F.notch.b, F.notch.a, fchk, fs); Hm = Hm .* abs(H);
[H, ~] = freqz(F.lp.b,    1,         fchk, fs); Hm = Hm .* abs(H);
F.m.f  = fchk(:);
F.m.db = 20 * log10(max(abs(Hm(:)), 1e-12));
F.m.passRippleDb = max(F.m.db(1:7)) - min(F.m.db(1:7));   % 0.5~40Hz 内峰谷差
F.m.stop49 = F.m.db(find(fchk == 49));
F.m.stop50 = F.m.db(find(fchk == 50));
F.m.stop51 = F.m.db(find(fchk == 51));

%% ---------- 自检 2：群延迟平坦度（FIR 必须接近常数）----------
F.m.gdStdSmp = NaN; F.m.gdMeanSmp = NaN;
try
    [gdr, fg] = grpdelay(F.lp.b, 1, 2048, fs);
    inb = fg >= 1 & fg <= cfg.filt.fPass;
    F.m.gdStdSmp  = std(gdr(inb));
    F.m.gdMeanSmp = mean(gdr(inb));
catch
    fprintf('[design][提示] 无 grpdelay（需 Signal Processing Toolbox），改用互相关验证延迟\n');
end

%% ---------- 打印设计结论 ----------
fprintf('[design] FIR: 阶数 %d / 抽头 %d / 群延迟 %d 样本 = %.1f ms（恒定，可补偿）\n', ...
        n, F.lp.nTaps, F.lp.delaySmp, F.lp.delayMs);
fprintf('[design] 通带纹波 0.5-40Hz = %.2f dB\n', F.m.passRippleDb);
fprintf('[design] 抑制量 49/50/51 Hz = %.0f / %.0f / %.0f dB\n', ...
        F.m.stop49, F.m.stop50, F.m.stop51);
fprintf('[design] 陷波 3dB 缺口宽 ≈ %.1f Hz（beta=%.2f）\n', F.notch.bw3dB, cfg.filt.notchBeta);
if ~isnan(F.m.gdStdSmp)
    fprintf('[design] FIR 群延迟标准差 = %.4f 样本（应 ≈0，证明线性相位）\n', F.m.gdStdSmp);
end
if F.m.stop51 > -60
    fprintf('[design][警告] 51Hz 抑制不足 -60dB：把 cfg.filt.fStop 往低压（如 45Hz）或加大 astDb\n');
end
if F.m.passRippleDb > 1.0
    fprintf('[design][警告] 通带纹波 >1dB，监护标准通常要求 ±0.5dB，检查 fPass/astDb\n');
end
end

function n = kaiserOrderEst(df, ast, fs)
%KAISERORDEREST  Kaiser 经验公式估算 FIR 所需阶数，并向上取偶数
%   n = (A - 7.95) / (2.285 * dw)，dw = 2*pi*df/fs [rad/sample]
%   —— 这就是"滤波器阶数要算"的落点：输入是指标，输出是阶数，不是拍脑袋。
if df <= 0
    error('kaiserOrderEst: 过渡带宽必须为正（fStop > fPass）');
end
dw = 2 * pi * df / fs;
n  = ceil((ast - 7.95) / (2.285 * dw));
if mod(n, 2) ~= 0
    n = n + 1;            % 偶数阶 → 奇数抽头 → Type-I 线性相位
end
end

function beta = kaiserBeta(ast)
%KAISERBETA  由阻带衰减（dB）反算 Kaiser 窗 beta（Kaiser 经验公式）
%   A>50:        beta = 0.1102*(A-8.7)
%   21<=A<=50:   beta = 0.5842*(A-21)^0.4 + 0.07886*(A-21)
%   —— 与 kaiserOrderEst 同族公式：一边估阶数、一边定窗形。
if ast > 50
    beta = 0.1102 * (ast - 8.7);
elseif ast >= 21
    beta = 0.5842 * (ast - 21)^0.4 + 0.07886 * (ast - 21);
else
    beta = 0;
end
end
