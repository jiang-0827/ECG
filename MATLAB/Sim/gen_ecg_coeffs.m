function gen_ecg_coeffs()
%GEN_ECG_COEFFS  运行设计器并把三级滤波系数导出为 C 文件（在 PC 上跑一次）
%
%   用法（在任意目录均可，脚本自动定位输出位置）：
%       gen_ecg_coeffs
%   或命令行：
%       matlab -batch "cd('...\EcgMcuC'); gen_ecg_coeffs"
%
%   输出（写到本文件所在目录，即 EcgMcuC/）：
%       ecg_coeffs.h  —— 抽头数/群延迟宏 + 系数 extern 声明
%       ecg_coeffs.c  —— const float 系数定义（编译后放 Flash，不占 RAM）
%
%   约定（与 EcgMcuSim/design_ecg_filters.m 一致）：
%     * 所有系数按 a(1) 归一化后导出（C 递推式里不再做除法）；
%     * 被关闭的级导出为"直通节" [1 0 0]/[1 0 0]（C 侧无需 if 分支）；
%     * 修改滤波指标后必须重跑本脚本，否则 C 系数与配置脱节。

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'EcgMcuSim'));

cfg = ecg_config();
F   = design_ecg_filters(cfg);   % 设计 + 自检（指标同时打印到命令窗口）

% ---- 归一化兜底（设计器已归一化，双重保险；直通节不受影响）----
hpB = F.hp.b(:).'    / F.hp.a(1);     hpA = F.hp.a(:).'    / F.hp.a(1);
ntB = F.notch.b(:).' / F.notch.a(1);  ntA = F.notch.a(:).' / F.notch.a(1);
lpB = F.lp.b(:).';

ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));

% ---- 写 ecg_coeffs.h ----
fid = fopen(fullfile(thisDir, 'ecg_coeffs.h'), 'w');
fprintf(fid, '/* ============================================================================\n');
fprintf(fid, ' * ECG_COEFFS  —— 滤波系数（由 gen_ecg_coeffs.m 自动生成，勿手改！）\n');
fprintf(fid, ' *\n');
fprintf(fid, ' * 生成来源 : EcgMcuSim/design_ecg_filters.m + ecg_config.m\n');
fprintf(fid, ' * 生成时间 : %s\n', ts);
fprintf(fid, ' * 自检记录 : FIR 阶数 %d / 抽头 %d / 群延迟 %d 样本 (%.1f ms)\n', ...
        F.lp.nTaps - 1, F.lp.nTaps, F.lp.delaySmp, F.lp.delayMs);
fprintf(fid, ' *            通带纹波 0.5-40Hz = %.2f dB\n', F.m.passRippleDb);
fprintf(fid, ' *            抑制量 49/50/51 Hz = %.0f / %.0f / %.0f dB\n', ...
        F.m.stop49, F.m.stop50, F.m.stop51);
fprintf(fid, ' *            系数已按 a(1) 归一化；被关闭的级为直通节 [1 0 0]/[1 0 0]\n');
fprintf(fid, ' * ==========================================================================*/\n');
fprintf(fid, '\n');
fprintf(fid, '#ifndef ECG_COEFFS_H\n#define ECG_COEFFS_H\n\n');
fprintf(fid, '#define ECG_LP_NTAPS      %d\n', F.lp.nTaps);
fprintf(fid, '#define ECG_LP_DELAY_SMP  %d\n', F.lp.delaySmp);
fprintf(fid, '#define ECG_LP_DELAY_MS   %.1ff\n', F.lp.delayMs);
fprintf(fid, '\n');
fprintf(fid, 'extern const float ECG_HP_B[3];\n');
fprintf(fid, 'extern const float ECG_HP_A[3];\n');
fprintf(fid, 'extern const float ECG_NOTCH_B[3];\n');
fprintf(fid, 'extern const float ECG_NOTCH_A[3];\n');
fprintf(fid, 'extern const float ECG_LP_B[ECG_LP_NTAPS];\n');
fprintf(fid, '\n#endif /* ECG_COEFFS_H */\n');
fclose(fid);

% ---- 写 ecg_coeffs.c ----
fid = fopen(fullfile(thisDir, 'ecg_coeffs.c'), 'w');
fprintf(fid, '/* 自动生成（gen_ecg_coeffs.m），勿手改！ 逐点对拍判据：1e-5 量级 */\n');
fprintf(fid, '#include "ecg_coeffs.h"\n\n');
writeArray(fid, 'ECG_HP_B',    hpB);
writeArray(fid, 'ECG_HP_A',    hpA);
writeArray(fid, 'ECG_NOTCH_B', ntB);
writeArray(fid, 'ECG_NOTCH_A', ntA);
writeArray(fid, 'ECG_LP_B',    lpB);
fclose(fid);

fprintf('[gen] 已生成:\n  %s\n  %s\n', ...
        fullfile(thisDir, 'ecg_coeffs.h'), fullfile(thisDir, 'ecg_coeffs.c'));
end

function writeArray(fid, name, v)
%WRITEARRAY 向 C 文件写入 const float 数组（每行 8 个，%.9e 保证 float 往返精度）
v = v(:).';
n = numel(v);
fprintf(fid, 'const float %s[%d] = {\n', name, n);
for k = 1:n
    if mod(k - 1, 8) == 0
        fprintf(fid, '    ');
    end
    fprintf(fid, '%.9ef', v(k));
    if k < n
        fprintf(fid, ',');
    end
    if mod(k, 8) == 0 && k < n
        fprintf(fid, '\n');
    end
end
fprintf(fid, '\n};\n\n');
end
