# -*- coding: utf-8 -*-
"""串口数据流乱码修复:
A. UART1.c: WriteUART1/ReadUART1 队列访问加临界区(防与中断并发破坏计数)
B. Main.c : 1s状态打印由printf直写改为WriteUART1队列发送(消除直写字节竞争)
"""
ROOT = r"E:\BaiduNetdiskDownload\立创·梁山派·天空星STM32F407VET6开发板资料（标准库）\第03章【立创·梁山派·天空星STM32F407开发板】软件资料\代码例程\011ADC采集\STM32F407_ProjectTemplate"
UART1_C = ROOT + r"\HW\UART1\UART1.c"
MAIN_C  = ROOT + r"\app\Main\Main.c"

def load(p):
    return open(p, 'rb').read().decode('gbk')

def splits(s):
    assert '\r\n' in s, 'expect CRLF'
    return s.split('\r\n')

def hits(lines, sub):
    return [i for i, l in enumerate(lines) if sub in l]

# ---------- A. UART1.c 临界区 ----------
lu = splits(load(UART1_C))

assert not hits(lu, '__disable_irq();'), 'UART1.c already patched?'

key = 'wLen = (u8)EnQueue(&s_structUARTSendCirQue, pBuf, len);'
h = hits(lu, key)
assert len(h) == 1, h
i = h[0]
lu[i:i] = ['  __disable_irq();  //临界区: 防与TXE中断并发修改队列计数(elemNum)']
lu.insert(i + 2, '  __enable_irq();')

key = 'rLen = (u8)DeQueue(&s_structUARTRecCirQue, pBuf, len);'
h = hits(lu, key)
assert len(h) == 1, h
i = h[0]
lu[i:i] = ['  __disable_irq();  //临界区: 防与接收中断并发修改队列计数']
lu.insert(i + 2, '  __enable_irq();')

# ---------- B. Main.c 1s状态行走队列 ----------
lm = splits(load(MAIN_C))

hi = hits(lm, 'printf("adc=%4d')
assert len(hi) == 1, hi
i = hi[0]
hj = hits(lm, 'GetADCOvrCnt());')
assert len(hj) == 1, hj
j = hj[0]
assert (j > i) and ((j - i) < 20), (i, j)

newblock = [
    '    /* 状态行改走发送队列(与波形数据同一写者): 原printf直写DR会与TXE',
    '     * 中断产生字节级竞争, 破坏接收端数据行的完整性(乱码) */',
    '    char arrStat[160];',
    '    int  statLen;',
    '',
    '    statLen = sprintf(arrStat, "adc=%4d %5lumV  rate=%4dHz  cnt=%lu  drop=%lu  queue=%3d/%d  wave=%d  filt=%5d  dmacnt=%lu  ovr=%lu\\r\\n",',
    '           s_iLastAdcData,',
    '           (unsigned long)GetADCVoltageMv(s_iLastAdcData),',
    '           GetADCSampleRate(),',
    '           (unsigned long)GetADCSampleCnt(),',
    '           (unsigned long)GetADCDropCnt(),',
    '           GetADCQueueLen(),',
    '           ADC1_BUF_SIZE,',
    '           GetWaveSendEnable(),',
    '           (int)s_filtDataLast,',
    '           (unsigned long)GetADCDmaCnt(),',
    '           (unsigned long)GetADCOvrCnt());',
    '    WriteUART1((u8*)arrStat, (u8)statLen);',
]
lm[i:j + 1] = newblock

open(UART1_C, 'wb').write('\r\n'.join(lu).encode('gbk'))
open(MAIN_C, 'wb').write('\r\n'.join(lm).encode('gbk'))
print('STREAM-FIX OK (UART1.c=%d lines, Main.c=%d lines)' % (len(lu), len(lm)))
