# -*- coding: utf-8 -*-
"""Main.c 导联脱落检测集成补丁:
1. include ecg_leadoff.h
2. 检测器实例 + 状态变量
3. InitSoftware: ecg_leadoff_init
4. ProcWaveData: 每样本 ecg_leadoff_step
5. VofaWaveTick: 输出第四通道(0=正常 1=脱落)
"""
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

# 1) include
h = hits(lm, '#include "ecg_heart.h"')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = ['#include "ecg_leadoff.h"']

# 2) 实例与状态变量
h = hits(lm, 'static  int16_t s_heartBpm = 0;')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = [
    'static  ecg_leadoff_t s_leadDet;     //导联脱落检测器(ADC2+PA1)',
    'static  uint8_t s_leadOff = 0;       //导联状态(0=正常 1=脱落)',
]

# 3) 初始化
h = hits(lm, 'ecg_heart_init(&s_heartDet);')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = ['  ecg_leadoff_init(&s_leadDet);  //初始化导联脱落检测(ADC2+PA1)']

# 4) 逐样本调用
h = hits(lm, 's_heartBpm = ecg_heart_step(&s_heartDet, s_filtDataLast);')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = ['    s_leadOff = ecg_leadoff_step(&s_leadDet);   //导联脱落检测(逐样本)']

# 5) VOFA 第四通道
h = hits(lm, '"%u,%d,%d\\n", (unsigned int)rawAdc, (int)filtVal, (int)s_heartBpm);')
assert len(h) == 1, h
i = h[0]
old = lm[i]
lm[i] = old.replace('"%u,%d,%d\\n", (unsigned int)rawAdc, (int)filtVal, (int)s_heartBpm);',
                    '"%u,%d,%d,%d\\n", (unsigned int)rawAdc, (int)filtVal, (int)s_heartBpm, (int)s_leadOff);')
assert lm[i] != old, 'sprintf replace failed'

open(MAIN_C, 'wb').write('\r\n'.join(lm).encode('gbk'))
print('PATCH-LEADOFF OK (Main.c=%d lines)' % len(lm))
