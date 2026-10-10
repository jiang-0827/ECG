function run_verify()
%RUN_VERIFY  C 滤波链 vs MATLAB 逐点参考 对拍（PC 端验证工具）
%
%   生成两份 MATLAB single 逐点参考（激励 = RecData 第一个 CSV 前 6000 点）：
%     ref_out.txt       FIR 用原版 fir_circ_step.m（内部向量化 sum）
%     ref_seq_out.txt   FIR 用逐次顺序累加（与 C 的 for 循环逐字对应）
%
%   说明：两份参考之差仅为"single 累加顺序"引起的量化噪声（361 项求和，
%   ~1e-5 相对量级）——即 EcgMcuSim/fir_circ_step.m 注释预告的现象。
%   C 实现与 ref_seq_out 语义一致（预期 ~1e-6 码值）；与 ref_out 的差异
%   属 MATLAB 向量 sum 的内部顺序，用宽松判据（1e-2 码值）判定。
%
%   运行前请先执行 gen_ecg_coeffs 生成系数文件。

thisDir = fileparts(mfilename('fullpath'));   % .../EcgMcuC/verify
projDir = fileparts(thisDir);                 % .../EcgMcuC
rootDir = fileparts(projDir);                 % .../ECGDynamicPrj
addpath(fullfile(rootDir, 'EcgMcuSim'));

cfg = ecg_config();
F   = design_ecg_filters(cfg);

% ---- 激励：项目内 CSV（12bit 码流，与 ADC 输出同构）----
f = dir(fullfile(rootDir, 'RecData', '*.csv'));
d = readmatrix(fullfile(f(1).folder, f(1).name));
N = min(numel(d), double(cfg.sim.n));
d = d(1:N);
fprintf('[verify] 激励 %s（前 %d 点）\n', f(1).name, N);

% ---- 两份 single 逐点参考 ----
refSum = runPointwise(F, d, false);
refSeq = runPointwise(F, d, true);

fid = fopen(fullfile(thisDir, 'ref_out.txt'),     'w'); fprintf(fid, '%.9e\n', double(refSum)); fclose(fid);
fid = fopen(fullfile(thisDir, 'ref_seq_out.txt'), 'w'); fprintf(fid, '%.9e\n', double(refSeq)); fclose(fid);
fprintf('[verify] 参考输出已存 ref_out.txt / ref_seq_out.txt\n');
fprintf('[verify] sum版 vs 顺序版：max|e| = %.3e（累加顺序噪声，符合注释预告）\n', ...
        max(abs(double(refSum) - double(refSeq))));

% ---- C 对拍（需要 mex 编译器；未配置则给出提示后跳过）----
oldDir = cd(thisDir);
mexOk = false;
try
    mex -O mex_ecg_filter.c ../ecg_filter.c
    mexOk = true;
catch ME
    fprintf('[verify] 跳过 C 对拍（本机无 mex 编译器配置）：%s\n', ME.message);
end
cd(oldDir);

if mexOk
    addpath(thisDir);
    yC = mex_ecg_filter(d);
    eSeq = max(abs(double(yC) - double(refSeq)));   % 主判据：1e-4 码值
    eSum = max(abs(double(yC) - double(refSum)));   % 宽松判据：1e-2 码值
    fprintf('[verify] C vs 顺序版：max|e| = %.3e（判据 1e-4）\n', eSeq);
    fprintf('[verify] C vs sum版 ：max|e| = %.3e（判据 1e-2，累加顺序噪声）\n', eSum);
    if (eSeq < 1e-4) && (eSum < 1e-2)
        fprintf('[verify] 通过\n');
    else
        fprintf('[verify] !!! 未通过，请检查 !!!\n');
    end
end
end

function ref = runPointwise(F, d, firSeq)
%RUNPOINTWISE  single 逐点参考；firSeq=true 时 FIR 用顺序累加（C 语义）
bHp = single(F.hp.b(:).');    aHp = single(F.hp.a(:).');
bN  = single(F.notch.b(:).'); aN  = single(F.notch.a(:).');
bLp = single(F.lp.b(:).');
stHp = [single(0) single(0)];
stN  = [single(0) single(0)];
stLp = struct('buf', zeros(1, numel(bLp), 'single'), 'idx', 0);
bias = single(F.bias);
N    = numel(d);
M    = numel(bLp);
ref  = zeros(N, 1, 'single');

for n = 1:N
    x = single(d(n)) - bias;
    [x, stHp] = biquad_df2t_step(bHp, aHp, x, stHp);
    [x, stN ] = biquad_df2t_step(bN,  aN,  x, stN);
    if firSeq
        % 顺序循环，与 ecg_filter.c 的 ecg_fir_step 逐字对应
        stLp.idx = stLp.idx + 1;
        if stLp.idx >= M
            stLp.idx = 0;
        end
        stLp.buf(stLp.idx + 1) = x;
        sel = stLp.idx + 1;
        acc = single(0);
        for k = 1:M
            acc = acc + bLp(k) * stLp.buf(sel);
            if sel == 1
                sel = M;
            else
                sel = sel - 1;
            end
        end
        x = acc;
    else
        [x, stLp] = fir_circ_step(bLp, x, stLp);
    end
    ref(n) = x;
end
end
