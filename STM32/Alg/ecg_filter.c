/* ============================================================================
 * ECG_FILTER  实现
 *
 * 对应 MATLAB ：EcgMcuSim/biquad_df2t_step.m（biquad）+ fir_circ_step.m（FIR）
 * 每个函数与 MATLAB 版本逐行对应；运算顺序（含 FIR 累加顺序）完全一致 ——
 * 这是"逐样本对拍"能收敛到 1e-5 量级的前提。
 * ==========================================================================*/

#include "ecg_filter.h"

void ecg_biquad_init(ecg_biquad_t *f, const float *b, const float *a)
{
    f->b  = b;
    f->a  = a;
    f->s1 = 0.0f;
    f->s2 = 0.0f;
}

float ecg_biquad_step(ecg_biquad_t *f, float x)
{
    float y;

    /* 三行递推：与 biquad_df2t_step.m 的 y / s1 / s2 三行一字不差 */
    y     = f->b[0] * x + f->s1;
    f->s1 = f->b[1] * x + f->s2 - f->a[1] * y;
    f->s2 = f->b[2] * x - f->a[2] * y;

    return y;
}

void ecg_fir_init(ecg_fir_t *f, const float *b, uint16_t n_taps)
{
    uint16_t k;

    f->b      = b;
    f->n_taps = n_taps;
    f->idx    = 0u;
    for (k = 0u; k < n_taps; k++) {
        f->buf[k] = 0.0f;
    }
}

float ecg_fir_step(ecg_fir_t *f, float x)
{
    uint16_t k;
    uint16_t sel;
    float    y = 0.0f;

    /* 写指针回绕并写入最新样本（C: if(++idx >= M) idx = 0;） */
    f->idx++;
    if (f->idx >= f->n_taps) {
        f->idx = 0u;
    }
    f->buf[f->idx] = x;

    /* 从最新往最老累加：y = b[0]*x[n] + b[1]*x[n-1] + ... + b[M-1]*x[n-M+1]
     * 本累加顺序与 MATLAB fir_circ_step.m 完全一致；
     * 与 CMSIS-DSP arm_fir_f32 的系数顺序相反（详见 fir_circ_step.m 注释），
     * 若改用 CMSIS 实现需重排系数，对拍判据放宽到 1e-5 量级。 */
    sel = f->idx;
    for (k = 0u; k < f->n_taps; k++) {
        y += f->b[k] * f->buf[sel];
        sel = (sel == 0u) ? (uint16_t)(f->n_taps - 1u) : (uint16_t)(sel - 1u);
    }

    return y;
}

void ecg_filt_init(ecg_filt_t *f)
{
    /* 三级系数均来自 ecg_coeffs.c（gen_ecg_coeffs.m 生成）：
     * HP_EN=0 时 ECG_HP_B/A 即直通节 [1 0 0]，无需条件分支 */
    ecg_biquad_init(&f->hp,    ECG_HP_B,    ECG_HP_A);
    ecg_biquad_init(&f->notch, ECG_NOTCH_B, ECG_NOTCH_A);
    ecg_fir_init(&f->lp, ECG_LP_B, ECG_LP_NTAPS);
    f->bias = (float)ECG_ADC_BIAS_CODE;
}

float ecg_filt_step(ecg_filt_t *f, float adc_code)
{
    float x;

    /* 级 0：先扣直流码值（整数相减，零相位、零代价） */
#if (ECG_FILT_BIAS_EN != 0u)
    x = adc_code - f->bias;
#else
    x = adc_code;
#endif

    x = ecg_biquad_step(&f->hp,    x);   /* 级 1：高通（默认直通节） */
    x = ecg_biquad_step(&f->notch, x);   /* 级 2：50 Hz 陷波 */
    x = ecg_fir_step(&f->lp,       x);   /* 级 3：FIR 低通 */

    return x;
}
