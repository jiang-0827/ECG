# -*- coding: utf-8 -*-
"""ADC 采样链诊断补丁(第二轮):
1. s_arrADC1Data 加 volatile (DMA目标规范写法, 排除读缓存)
2. TIM2中断: OVR计数 + DMA搬运(TCIF)计数
3. ADC.c/ADC.h 新增 GetADCOvrCnt / GetADCDmaCnt
4. Main.c 1s打印增加 dmacnt= ovr= 字段
"""
import sys

ROOT = r"E:\BaiduNetdiskDownload\立创·梁山派·天空星STM32F407VET6开发板资料（标准库）\第03章【立创·梁山派·天空星STM32F407开发板】软件资料\代码例程\011ADC采集\STM32F407_ProjectTemplate"
ADC_C  = ROOT + r"\HW\ADC\ADC.c"
ADC_H  = ROOT + r"\HW\ADC\ADC.h"
MAIN_C = ROOT + r"\app\Main\Main.c"

def load(p):
    return open(p, 'rb').read().decode('gbk')

def splits(s):
    assert '\r\n' in s, 'expect CRLF'
    return s.split('\r\n')

def hits(lines, sub):
    return [i for i, l in enumerate(lines) if sub in l]

# ================= ADC.c =================
lc = splits(load(ADC_C))

# 1) volatile
h = hits(lc, 'static u16 s_arrADC1Data;')
assert len(h) == 1, h
lc[h[0]] = 'static volatile u16 s_arrADC1Data;       //当前ADC转换结果(DMA后台写入,必须volatile防读缓存)'

# 2) 计数器变量
h = hits(lc, 'static u32 s_iDropCnt')
assert len(h) == 1, h
i = h[0]
lc[i + 1:i + 1] = [
    'static u32 s_iOvrCnt       = 0;                       //ADC溢出(OVR)次数(诊断,正常应保持0)',
    'static u32 s_iDmaCnt       = 0;                       //DMA搬运次数(诊断,正常每秒增加约采样率个)',
]

# 3) OVR 计数
h = hits(lc, 'ADC_ClearFlag(ADC1, ADC_FLAG_OVR);')
assert len(h) == 1, h
i = h[0]
assert lc[i + 1].strip() == '}', repr(lc[i + 1])
lc.insert(i, '      s_iOvrCnt++;')

# 4) TCIF 搬运计数 (插在 OVR 块闭合 } 之后)
h = hits(lc, 'ADC_ClearFlag(ADC1, ADC_FLAG_OVR);')
i = h[0]
assert lc[i + 1].strip() == '}', repr(lc[i + 1])
tcif = [
    '',
    '    /* DMA搬运计数(诊断): 每搬1个样本DMA置TCIF标志, 清标志并计数(判断搬运链死活) */',
    '    if(DMA_GetFlagStatus(DMA2_Stream0, DMA_FLAG_TCIF0) != RESET)',
    '    {',
    '      DMA_ClearFlag(DMA2_Stream0, DMA_FLAG_TCIF0);',
    '      s_iDmaCnt++;',
    '    }',
]
lc[i + 2:i + 2] = tcif

# 5) Get API 实现
h = hits(lc, 'return(s_iDropCnt);')
assert len(h) == 1, h
i = h[0]
assert lc[i + 1].strip() == '}', repr(lc[i + 1])
funcs = [
    '',
    '/*********************************************************************************************************',
    '* 函数名称：GetADCOvrCnt',
    '* 功能功能：读取ADC溢出(OVR)累计次数(诊断用, 正常应保持0)',
    '* 输入参数：void',
    '* 输出参数：void',
    '* 返 回 值：OVR累计次数',
    '* 创建日期：2026年09月21日',
    '* 注    记：',
    '**********************************************************************************************************/',
    'u32  GetADCOvrCnt(void)',
    '{',
    '  return(s_iOvrCnt);',
    '}',
    '',
    '/*********************************************************************************************************',
    '* 函数名称：GetADCDmaCnt',
    '* 功能功能：读取DMA搬运累计次数(诊断用, 正常每秒增加约采样率个)',
    '* 输入参数：void',
    '* 输出参数：void',
    '* 返 回 值：DMA搬运累计次数',
    '* 创建日期：2026年09月21日',
    '* 注    记：',
    '**********************************************************************************************************/',
    'u32  GetADCDmaCnt(void)',
    '{',
    '  return(s_iDmaCnt);',
    '}',
]
lc[i + 2:i + 2] = funcs

# ================= ADC.h =================
lh = splits(load(ADC_H))
h = hits(lh, 'GetADCDropCnt(void);')
assert len(h) == 1, h
i = h[0]
lh[i + 1:i + 1] = [
    'u32   GetADCOvrCnt(void);        //读取ADC溢出(OVR)次数(诊断,正常应为0)',
    'u32   GetADCDmaCnt(void);        //读取DMA搬运次数(诊断,正常每秒增加约采样率)',
]

# ================= Main.c =================
lm = splits(load(MAIN_C))
h = hits(lm, 'filt=%5d')
assert len(h) == 1, h
i = h[0]
old = lm[i]
lm[i] = old.replace('filt=%5d\\r\\n",', 'filt=%5d  dmacnt=%lu  ovr=%lu\\r\\n",')
assert lm[i] != old, 'printf fmt replace failed'

h = hits(lm, '(int)s_filtDataLast);')
assert len(h) == 1, h
j = h[0]
old = lm[j]
lm[j] = old.replace('(int)s_filtDataLast);', '(int)s_filtDataLast, (unsigned long)GetADCDmaCnt(), (unsigned long)GetADCOvrCnt());')
assert lm[j] != old, 'printf arg replace failed'

# ================= 统一写回 =================
open(ADC_C, 'wb').write('\r\n'.join(lc).encode('gbk'))
open(ADC_H, 'wb').write('\r\n'.join(lh).encode('gbk'))
open(MAIN_C, 'wb').write('\r\n'.join(lm).encode('gbk'))
print('PATCH2 OK (ADC.c=%d lines, ADC.h=%d, Main.c=%d)' % (len(lc), len(lh), len(lm)))
