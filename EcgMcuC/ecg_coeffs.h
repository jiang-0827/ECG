/* ============================================================================
 * ECG_COEFFS  —— 滤波系数（由 gen_ecg_coeffs.m 自动生成，勿手改！）
 *
 * 生成来源 : EcgMcuSim/design_ecg_filters.m + ecg_config.m
 * 生成时间 : 2026-09-21 09:54:37
 * 自检记录 : FIR 阶数 360 / 抽头 361 / 群延迟 180 样本 (360.0 ms)
 *            通带纹波 0.5-40Hz = 6.43 dB
 *            抑制量 49/50/51 Hz = -99 / -240 / -130 dB
 *            系数已按 a(1) 归一化；被关闭的级为直通节 [1 0 0]/[1 0 0]
 * ==========================================================================*/

#ifndef ECG_COEFFS_H
#define ECG_COEFFS_H

#define ECG_LP_NTAPS      361
#define ECG_LP_DELAY_SMP  180
#define ECG_LP_DELAY_MS   360.0f

extern const float ECG_HP_B[3];
extern const float ECG_HP_A[3];
extern const float ECG_NOTCH_B[3];
extern const float ECG_NOTCH_A[3];
extern const float ECG_LP_B[ECG_LP_NTAPS];

#endif /* ECG_COEFFS_H */
