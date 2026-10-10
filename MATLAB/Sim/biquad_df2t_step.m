function [y, st] = biquad_df2t_step(b, a, x, st)
%BIQUAD_DF2T_STEP  二阶节 Direct-Form-II-Transposed，逐样本递推
%   [y, st] = biquad_df2t_step(b, a, x, st)
%      b  = [b0 b1 b2]（已按 a0 归一化）
%      a  = [1  a1 a2]
%      st = [s1 s2]   ← 跨样本常驻的状态，第一次调用传 [0 0]
%
%   递推式（这就是要在 C 里一字不差照抄的三行）：
%       y[n]  = b0*x[n] + s1
%       s1    = b1*x[n] + s2 - a1*y[n]
%       s2    = b2*x[n] - a2*y[n]
%
%   ---- 为什么选 DF2T ----
%   DF1  要存 x[n-1],x[n-2],y[n-1],y[n-2] 共 4 个状态；
%   DF2T 只要 2 个状态，且乘法顺序与系数数组同向 → C 里最容易展开、RAM 占用最小。
%   ---- 为什么状态必须常驻（这是实时与离线的分水岭）----
%   递推滤波器的"历史"全部压缩在 st 里。MATLAB 原工程每 10 个样本对整 2048 点重算一次
%   filter()，等于每次都把状态强行清零重来，所以才会出现"每屏边界跳变"，
%   才需要 FilterECG.m 里那个 248 点前缀 gFiltStartData 去掩盖。
%   逐点递推天然连续，那套前缀技巧在单片机上整个不需要 —— 移植后你会甩掉一个包袱。
%   ---- 与 MATLAB 的等价性 ----
%   本函数逐点输出 == filter(b,a,x) 整段输出（双精度下误差 ~1e-13）。
%   这条等价关系就是 run_monitor_sim 自检表的第 1 项判据。
y     = b(1) * x + st(1);
st(1) = b(2) * x + st(2) - a(2) * y;
st(2) = b(3) * x - a(3) * y;
end
