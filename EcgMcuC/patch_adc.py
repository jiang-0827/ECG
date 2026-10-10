# -*- coding: utf-8 -*-
"""ADC.c 一次性行级补丁: 修复 ADC/DMA 初始化顺序 + 增加 OVR 自愈"""
import sys

PATH = r"E:\BaiduNetdiskDownload\立创·梁山派·天空星STM32F407VET6开发板资料（标准库）\第03章【立创·梁山派·天空星STM32F407开发板】软件资料\代码例程\011ADC采集\STM32F407_ProjectTemplate\HW\ADC\ADC.c"

def main():
    with open(PATH, 'rb') as f:
        raw = f.read()
    txt = raw.decode('gbk')
    assert '\r\n' in txt, 'expect CRLF file'
    lines = txt.split('\r\n')

    def hits(sub):
        return [i for i, l in enumerate(lines) if sub in l]

    ht = hits('ConfigTimer2(psc, arr);')
    ha = hits('ConfigADC1();')
    hd = hits('ConfigDMA2Stream0();')
    assert len(ht) == 1, ('Timer2 call hits', ht)
    assert len(ha) == 1, ('ADC1 call hits', ha)
    assert len(hd) == 1, ('DMA call hits', hd)
    t, a, d = ht[0], ha[0], hd[0]
    assert a == t + 1 and d == t + 2, ('unexpected layout', t, a, d)

    # 1) 顺序: Timer2,ADC1,DMA2 -> DMA2,ADC1,Timer2 (DMA先就绪, TIM2最后启动)
    lines[t:t + 3] = [lines[d], lines[a], lines[t]]

    # 2) OVR 自愈: 插到 TIM2 中断里 s_iSampleCnt++ 之后
    hs = hits('s_iSampleCnt++')
    assert len(hs) == 1, ('s_iSampleCnt hits', hs)
    j = hs[0]
    ins = [
        '    /* F4防御: 采样链溢出(OVR)若未及时清除会阻塞后续转换, 这里检测到即清(自愈) */',
        '    if(ADC_GetFlagStatus(ADC1, ADC_FLAG_OVR) != RESET)',
        '    {',
        '      ADC_ClearFlag(ADC1, ADC_FLAG_OVR);',
        '    }',
    ]
    lines[j + 1:j + 1] = ins

    out = '\r\n'.join(lines)
    with open(PATH, 'wb') as f:
        f.write(out.encode('gbk'))

    print('PATCH OK  (lines=%d)' % len(lines))

if __name__ == '__main__':
    main()
