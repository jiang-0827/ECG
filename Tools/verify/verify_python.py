#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_python.py -- 无 C 编译器环境下的 C 滤波链逐样本复刻对拍（PC 端验证工具）

1) Parse coefficients from ../ecg_coeffs.c (also validates the generated file)
2) Replicate ecg_filter.c in float32 bit-exactly (same op order, incl. FIR sum order)
3) Compare against both MATLAB references produced by run_verify.m:
     ref_seq_out.txt  FIR sequential accumulation (same semantics as C)  <- primary
     ref_out.txt      FIR via vectorized sum (original fir_circ_step.m)
"""
import re
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent      # .../EcgMcuC/verify
PROJ = HERE.parent                          # .../EcgMcuC
ROOT = PROJ.parent                          # .../ECGDynamicPrj

def parse_coeffs(path: Path):
    txt = path.read_text(encoding='utf-8')
    out = {}
    for m in re.finditer(r'const float (\w+)\s*\[(\d+)\]\s*=\s*\{([^}]*)\}', txt):
        name, n, body = m.group(1), int(m.group(2)), m.group(3)
        vals = [np.float32(v) for v in re.findall(r'([-+]?\d+\.\d+e[-+]\d+)', body)]
        assert len(vals) == n, f'{name}: expected {n} coeffs, parsed {len(vals)}'
        out[name] = np.array(vals, dtype=np.float32)
    return out

def main():
    co = parse_coeffs(PROJ / 'ecg_coeffs.c')
    b_hp, a_hp = co['ECG_HP_B'], co['ECG_HP_A']
    b_nt, a_nt = co['ECG_NOTCH_B'], co['ECG_NOTCH_A']
    b_lp = co['ECG_LP_B']
    print(f'[coeffs] HP {b_hp.shape}, NOTCH {b_nt.shape}, LP {b_lp.shape}')
    print(f'[coeffs] notch b={b_nt}, a={a_nt}')

    csvs = sorted((ROOT / 'RecData').glob('*.csv'))
    codes = np.loadtxt(csvs[0], dtype=np.float64)
    refSeq = np.loadtxt(HERE / 'ref_seq_out.txt', dtype=np.float64).astype(np.float32)
    refSum = np.loadtxt(HERE / 'ref_out.txt',     dtype=np.float64).astype(np.float32)
    N = len(refSeq)
    codes = codes[:N]
    print(f'[stim]   {csvs[0].name}  (first {N} points)')

    # Replicate ecg_filter.c (float32, identical evaluation order)
    bias = np.float32(2048)          # ECG_ADC_BIAS_CODE
    s1h = s2h = np.float32(0.0)
    s1n = s2n = np.float32(0.0)
    M = b_lp.shape[0]
    buf = np.zeros(M, dtype=np.float32)
    idx = 0
    y_out = np.zeros(N, dtype=np.float32)

    for i in range(N):
        x = np.float32(np.float32(codes[i]) - bias)
        # biquad HP (straight-through when hp disabled: coefficients say [1 0 0])
        y = np.float32(np.float32(b_hp[0] * x) + s1h)
        s1h = np.float32(np.float32(np.float32(b_hp[1] * x) + s2h) - np.float32(a_hp[1] * y))
        s2h = np.float32(np.float32(b_hp[2] * x) - np.float32(a_hp[2] * y))
        x = y
        # biquad notch
        y = np.float32(np.float32(b_nt[0] * x) + s1n)
        s1n = np.float32(np.float32(np.float32(b_nt[1] * x) + s2n) - np.float32(a_nt[1] * y))
        s2n = np.float32(np.float32(b_nt[2] * x) - np.float32(a_nt[2] * y))
        x = y
        # FIR circular buffer (newest -> oldest, same as C)
        idx += 1
        if idx >= M:
            idx = 0
        buf[idx] = x
        sel = idx
        acc = np.float32(0.0)
        for k in range(M):
            acc = np.float32(acc + np.float32(b_lp[k] * buf[sel]))
            sel = M - 1 if sel == 0 else sel - 1
        y_out[i] = acc

    np.savetxt(HERE / 'c_replica.txt', y_out.astype(np.float64), fmt='%.9e')

    def cmp(name, a, b):
        err = np.abs(a.astype(np.float64) - b.astype(np.float64))
        rel = err / np.maximum(np.abs(b.astype(np.float64)), 1e-6)
        print(f'[cmp] {name}: max abs err = {err.max():.3e}, max rel err = {rel.max():.3e}')
        return err.max()

    e_seq = cmp('C-replica vs ref_seq (primary)', y_out, refSeq)
    e_sum = cmp('C-replica vs ref_sum        ', y_out, refSum)
    ok = (e_seq < 1e-4) and (e_sum < 1e-2)
    print('[cmp] ' + ('PASS (primary criterion 1e-4 ADC code)' if ok else '!!! FAIL !!!'))

if __name__ == '__main__':
    main()
