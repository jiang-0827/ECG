# -*- coding: utf-8 -*-
"""Main.c 心率模块集成补丁:
1. include ecg_heart.h
2. 心率检测器全局实例 + 最新bpm变量
3. InitSoftware: ecg_heart_init
4. ProcWaveData: 每样本 ecg_heart_step
5. VofaWaveTick: 输出第三通道(心率bpm)
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
h = hits(lm, '#include "ecg_filter.h"')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = ['#include "ecg_heart.h"']

# 2) 全局实例
h = hits(lm, 'static  float s_filtDataLast = 0.0f;')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = [
    'static  ecg_heart_t s_heartDet;      //心率检测器(逐点流式, R峰+中位数RR)',
    'static  int16_t s_heartBpm = 0;      //最新心率(bpm, 0=无效)',
]

# 3) 初始化
h = hits(lm, 'ecg_filt_init(&s_ecgFilter);')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = ['  ecg_heart_init(&s_heartDet);  //初始化心率检测器']

# 4) 逐样本调用(接在滤波链之后)
h = hits(lm, 's_filtDataLast = ecg_filt_step(&s_ecgFilter, (float)adcData);')
assert len(h) == 1, h
i = h[0]
lm[i + 1:i + 1] = ['    s_heartBpm = ecg_heart_step(&s_heartDet, s_filtDataLast);   //心率检测(逐样本)']

# 5) VOFA 第三通道
h = hits(lm, '"%u,%d\\n", (unsigned int)rawAdc, (int)filtVal);')
assert len(h) == 1, h
i = h[0]
old = lm[i]
lm[i] = old.replace('"%u,%d\\n", (unsigned int)rawAdc, (int)filtVal);',
                    '"%u,%d,%d\\n", (unsigned int)rawAdc, (int)filtVal, (int)s_heartBpm);')
assert lm[i] != old, 'sprintf replace failed'

open(MAIN_C, 'wb').write('\r\n'.join(lm).encode('gbk'))
print('PATCH-HEART OK (Main.c=%d lines)' % len(lm))
