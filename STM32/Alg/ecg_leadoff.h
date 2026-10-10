#ifndef ECG_LEADOFF_H
#define ECG_LEADOFF_H

/* ============================================================================
 * ECG_LEADOFF  导联脱落检测（LEAD_OFF 模拟输出 → ADC2 独立采样 → 去抖判决）
 *
 * 硬件：心电板 LEAD_OFF 输出 → 天空星 PA1（板载丝印 A01, ADC2_IN1）
 *   实测（本板）：电极正常 ≈ 20mV（≈25 码）；脱落 ≈ 3.0V（≈3723 码）
 *   3.0V ≤ 3.3V(VDDA) → 直连安全，无需分压
 *
 * 设计：
 *   - 使用 ADC2 软件触发单次转换，完全独立于 ADC1 的 TIM2+DMA 流水线；
 *   - 每样本(500Hz)调用一次 step()：启动转换 → 等待约 23μs → 读码值 → 去抖；
 *   - 去抖：码值 > ECG_LO_THR_CODE 计数递增、反之递减（对称），满
 *     ECG_LO_DEBOUNCE(50) 判脱落（建立/解除均为 100ms，防抖）；
 *   - 超时保护：EOC 等待带计数上限，异常时不会卡死采集任务。
 *
 * 用法：
 *      static ecg_leadoff_t g_lo;
 *      ecg_leadoff_init(&g_lo);                // 上电初始化(配置ADC2+PA1)
 *      uint8_t off = ecg_leadoff_step(&g_lo);  // 每样本调用; 返回 0=正常 1=脱落
 * ==========================================================================*/

#include <stdint.h>

typedef struct {
    uint16_t cnt;        /* 去抖计数 0..ECG_LO_DEBOUNCE */
    uint16_t lastCode;   /* 最近一次 LEAD_OFF 码值(诊断用) */
    uint8_t  status;     /* 0=正常 1=脱落 */
} ecg_leadoff_t;

void    ecg_leadoff_init(ecg_leadoff_t *h);
uint8_t ecg_leadoff_step(ecg_leadoff_t *h);

#endif /* ECG_LEADOFF_H */
