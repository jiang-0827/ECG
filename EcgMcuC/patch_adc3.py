# -*- coding: utf-8 -*-
"""ADC 采样链修复(第三轮): 使能 DDS —— 最后一次DMA传输后持续产生请求
根因: F4 ADC 默认在"last DMA transfer"后停止产生DMA请求;
      本工程 DMA 为 BufferSize=1 + 循环模式, 第一次搬运即构成 last transfer,
      导致数据只更新一次(诊断计数 dmacnt=1 证实)。
"""
ROOT = r"E:\BaiduNetdiskDownload\立创·梁山派·天空星STM32F407VET6开发板资料（标准库）\第03章【立创·梁山派·天空星STM32F407开发板】软件资料\代码例程\011ADC采集\STM32F407_ProjectTemplate"
ADC_C = ROOT + r"\HW\ADC\ADC.c"

def load(p):
    return open(p, 'rb').read().decode('gbk')

def splits(s):
    assert '\r\n' in s, 'expect CRLF'
    return s.split('\r\n')

def hits(lines, sub):
    return [i for i, l in enumerate(lines) if sub in l]

lc = splits(load(ADC_C))

assert not hits(lc, 'ADC_DMARequestAfterLastTransferCmd(ADC1'), 'already patched'
h = hits(lc, 'ADC_DMACmd(ADC1, ENABLE);')
assert len(h) == 1, h
i = h[0]
lc[i + 1:i + 1] = [
    '  ADC_DMARequestAfterLastTransferCmd(ADC1, ENABLE);  //关键: 设置DDS=1, 最后一次DMA传输后继续产生请求(否则只搬1次就停)',
]

open(ADC_C, 'wb').write('\r\n'.join(lc).encode('gbk'))
print('PATCH3 OK (ADC.c=%d lines)' % len(lc))
