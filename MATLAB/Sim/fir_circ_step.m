function [y, st] = fir_circ_step(b, x, st)
%FIR_CIRC_STEP  线性相位 FIR 的逐样本计算（环形缓冲，与 C 实现同构）
%   [y, st] = fir_circ_step(b, x, st)
%      b  = FIR 系数（列或行向量均可）
%      st = struct('buf', zeros(1,M), 'idx', 0)   ← 首次调用这样造
%
%   ---- 为什么用环形缓冲而不是移位数组 ----
%   移位写法 y = b' * xbuf 之前要 memmove 整个 buf：361 抽头 × 4B × 500 SPS = 722 KB/s，
%   在 C 里是纯浪费；环形写法每样本只写 1 个 float。
%   ---- 为什么 st.buf 必须跨样本常驻 ----
%   它保存"最近 M 个样本"，是 FIR 唯一的记忆；新建数组等于把 FIR 退化成单点乘系数。
%   ---- 与 CMSIS arm_fir_f32 的唯一差异 ----
%   本函数从"最新样本"往老样本累加（b(1)*x[n] + b(2)*x[n-1] + ...）；
%   arm_fir 的系数顺序相反（b(0) 乘最老样本）。
%   double 下两者结果相同；single 下累加顺序不同会带来 ~1e-7 相对差。
%   ⇒ 移植对拍时判据要按 1e-5 量级放宽，别去追 0 误差，那是白费劲。
M = numel(b);
bv = b(:).';

st.idx = st.idx + 1;
if st.idx >= M                     % 写指针回绕（C: if(++idx >= M) idx = 0;）
    st.idx = 0;
end
st.buf(st.idx + 1) = x;            % MATLAB 1 基 ↔ C 0 基的偏移就藏在这 +1 里

sel = mod(st.idx - (0:M-1), M) + 1;    % 从最新往最老读出 M 个索引
y   = sum(bv .* st.buf(sel));
end
