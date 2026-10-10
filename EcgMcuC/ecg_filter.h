#ifndef ECG_FILTER_H
#define ECG_FILTER_H

/* ============================================================================
 * ECG_FILTER  监护型滤波链逐点实现（bias → 0.5Hz 高通 → 50Hz 陷波 → FIR 低通）
 *
 * 对应 MATLAB ：EcgMcuSim/biquad_df2t_step.m + fir_circ_step.m
 *               （运行期代码的 C 移植。设计期代码 design_ecg_filters.m 不上机，
 *                其产物由 gen_ecg_coeffs.m 固化为 ecg_coeffs.h/.c）
 *
 * 沿袭的设计约束（移植时别改）：
 *   1) 被关掉的级写成"直通节" b=[1 0 0], a=[1 0 0]：照常调用同一份 biquad 代码，
 *      不引入 if 分支 —— 分支越少，移植期越不容易错。
 *   2) 系数一律按 a[0] 归一化（gen_ecg_coeffs.m 导出时完成），
 *      递推式里不出现除法（M4F 的 VDIV.F32 ≈14 cycle，乘加只有 3~7 cycle）。
 *   3) FIR 为"偶数阶 = 奇数抽头"Type-I 线性相位，群延迟是整数样本
 *      （ECG_LP_DELAY_SMP），波形时间对齐时按该常量整体平移即可。
 *
 * 用法（500 Hz 定时触发里逐样本调用，单文件无任何外设依赖）：
 *
 *      #include "ecg_filter.h"
 *
 *      static ecg_filt_t g_ecg;              // 状态常驻；FIR 缓冲约 1.4 KB
 *
 *      void app_init(void)
 *      {
 *          ecg_filt_init(&g_ecg);            // 上电初始化一次
 *      }
 *
 *      void on_adc_sample(uint16_t adc_code) // 每 2 ms 一次
 *      {
 *          float y = ecg_filt_step(&g_ecg, (float)adc_code);
 *          // y = 滤波后波形（去直流、50Hz 抑制、40Hz 低通），单位仍是 ADC 码值域
 *          // 换算电极端电压：uV = y * ECG_ADC_UV_PER_LSB
 *      }
 *
 * 输出与 MATLAB 逐点仿真（single 精度）逐样本等价，对拍判据 1e-5 量级
 * （single 累加顺序差异，详见 EcgMcuSim/fir_circ_step.m 注释）。
 * ==========================================================================*/

#include <stdint.h>
#include "ecg_config.h"
#include "ecg_coeffs.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ---- 二阶节 Direct-Form-II-Transposed（要在 C 里一字不差照抄的三行递推）----
 *
 *   y[n] = b0*x[n] + s1
 *   s1   = b1*x[n] + s2 - a1*y[n]
 *   s2   = b2*x[n] - a2*y[n]
 *
 * DF2T 只存 2 个状态（DF1 要存 4 个），乘法顺序与系数数组同向，RAM 占用最小。
 * 系数指针直接指向 Flash 里的 const 数组（ecg_coeffs.c），不占 RAM。 */
typedef struct {
    const float *b;   /* [b0 b1 b2]，已按 a0 归一化 */
    const float *a;   /* [1  a1 a2] */
    float        s1;  /* 跨样本常驻状态 */
    float        s2;  /* 跨样本常驻状态 */
} ecg_biquad_t;

/* ---- 线性相位 FIR 环形缓冲 ----
 * 环形写法每样本只写 1 个 float；移位写法要搬运整个数组
 * （361 抽头 × 4B × 500SPS = 722 KB/s，纯浪费）。
 * buf 是 FIR 唯一的记忆，必须跨样本常驻；长度 = 抽头数（编译期常量）。 */
typedef struct {
    const float *b;                  /* FIR 系数 ECG_LP_B */
    uint16_t     n_taps;             /* 抽头数 = ECG_LP_NTAPS */
    uint16_t     idx;                /* 环形写指针（0 基） */
    float        buf[ECG_LP_NTAPS];  /* 最近 n_taps 个输入样本 */
} ecg_fir_t;

/* ---- 三级滤波链 ---- */
typedef struct {
    ecg_biquad_t hp;     /* 级 1：0.5 Hz 高通（HP_EN=0 时系数为直通节） */
    ecg_biquad_t notch;  /* 级 2：50 Hz 陷波 */
    ecg_fir_t    lp;     /* 级 3：FIR 低通 */
    float        bias;   /* 直流码值（ECG_ADC_BIAS_CODE），最先扣除 */
} ecg_filt_t;

void  ecg_biquad_init(ecg_biquad_t *f, const float *b, const float *a);
float ecg_biquad_step(ecg_biquad_t *f, float x);
void  ecg_fir_init(ecg_fir_t *f, const float *b, uint16_t n_taps);
float ecg_fir_step(ecg_fir_t *f, float x);
void  ecg_filt_init(ecg_filt_t *f);
float ecg_filt_step(ecg_filt_t *f, float adc_code);

#ifdef __cplusplus
}
#endif

#endif /* ECG_FILTER_H */
