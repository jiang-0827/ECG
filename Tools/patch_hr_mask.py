# -*- coding: utf-8 -*-
"""Main.c 小补丁: 导联脱落时心率强制显示0(监护规范)"""
ROOT = r"E:\BaiduNetdiskDownload\立创·梁山派·天空星STM32F407VET6开发板资料（标准库）\第03章【立创·梁山派·天空星STM32F407开发板】软件资料\代码例程\011ADC采集\STM32F407_ProjectTemplate"
MAIN_C = ROOT + r"\app\Main\Main.c"

def load(p):
    return open(p, 'rb').read().decode('gbk')

def splits(s):
    assert '\r\n' in s, 'expect CRLF'
    return s.split('\r\n')

def hits(lines, sub):
    return [i for i, l in enumerate(lines) if sub in l]

lm = splits(load(MAIN_C))

assert not hits(lm, 's_heartBpm = 0;   //导联脱落时'), 'already patched?'
h = hits(lm, 's_leadOff = ecg_leadoff_step(&s_leadDet);')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = [
    '    if(s_leadOff != 0)',
    '    {',
    '      s_heartBpm = 0;   //导联脱落时心率无意义, 强制显示0(监护规范)',
    '    }',
]

open(MAIN_C, 'wb').write('\r\n'.join(lm).encode('gbk'))
print('PATCH-MASK OK (Main.c=%d lines)' % len(lm))
