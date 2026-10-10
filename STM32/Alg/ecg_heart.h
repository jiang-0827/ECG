#ifndef ECG_HEART_H
#define ECG_HEART_H

/* ============================================================================
 * ECG_HEART  逐点流式心率检测（R峰定位 + 中位数RR → bpm）
 *
 * 对应原型 ：MATLAB CalcHeartRate.m（findpeaks + median(RR)）
 * 对应参考 ：桌面"心率加波形"工程 mcu/c/ecg_filter.c 的 ecg_heart_rate
 *            （那份是成帧版；本模块是 500Hz 逐样本在线版）
 *
 * 算法（全部流式，无 malloc，无 math.h）：
 *   1) 滑窗极值：最近 ECG_HR_WIN_LEN(2048) 个样本按 ECG_DET_BLK_LEN(64)
 *      分块追踪极值，块提交时刷新窗 max/min —— 4 秒自适应窗；
 *   2) 自适应门限：thr = min + alpha*(max-min)，alpha=0.6（参考工程标定值，
 *      配合不应期可挡掉 T 波）；
 *   3) R峰检测状态机：样本首次过阈 → 跟踪候选峰（记录峰值与其"最后创新高"
 *      位置）；峰后连续 ECG_DET_CONFIRM_FALL 个样本回落 → 确认 R 峰；
 *      确认后进入 ECG_HR_REFRACTORY_SMP(100 样本=0.2s) 不应期，忽略 T 波/噪声；
 *   4) 心率：R-R 间期入环形缓冲（最近 8 个），取中位数
 *      → bpm = 60*Fs/medRR（500Hz 下即 30000/medRR），范围 [30,250] 有效。
 *
 * 边界与保护：
 *   - 窗峰峰值 < ECG_HR_ABS_MIN → 判"信号丢失"：清 RR 历史、心率输出 0；
 *   - 上电前 2 秒（半个窗）不输出心率，避免未标定的窗极值误检；
 *   - 不应期 0.2s（100 样本），可测上限 300bpm（满足验收要求 240bpm）；
 *     从峰位置起算（扣除确认延迟），避免高频心率周期性丢峰。
 *
 * 用法（在滤波链之后逐样本调用）：
 *      static ecg_heart_t g_hr;                 // 约 320 字节 RAM
 *      ecg_heart_init(&g_hr);                   // 上电初始化一次
 *      int16_t bpm = ecg_heart_step(&g_hr, y);  // y = 滤波后样本; 返回心率, 0=无效
 * ==========================================================================*/

#include <stdint.h>
#include "ecg_config.h"

/* 滑窗分块极值的块数 = 2048/64 = 32 块 */
#define ECG_HR_BLK_NUM          (ECG_HR_WIN_LEN / ECG_DET_BLK_LEN)
/* 自适应门限系数：thr = min + alpha*(max-min) */
#define ECG_HR_THR_ALPHA        0.6f
/* 峰确认所需连续回落样本数（沿用 ecg_config.h 的检测参数） */
#define ECG_HR_CONFIRM_FALL     ECG_DET_CONFIRM_FALL
/* 不应期（样本数）：0.2s @500Hz → 可测上限 300bpm（验收要求 240bpm）。
 * 注：0.5s 版本在 120bpm 处周期性丢峰(被显示成80)；0.3s 版本经 150bpm
 * 实测验证；为覆盖 240bpm 验收再降至 0.2s(T 波由 0.6 门限兜底)。 */
#define ECG_HR_REFRACTORY_SMP   100u
/* 至少累计多少个 RR 才输出心率（抗单次异常） */
#define ECG_HR_MIN_RR_OUT       2u
/* RR 合法性上限（样本） = 60*Fs / 心率下限 */
#define ECG_HR_RR_MAX           (uint32_t)(60.0f * ECG_FS / (float)ECG_HR_HR_MIN)

typedef struct {
    /* ---- 滑窗分块极值（自适应门限） ---- */
    uint16_t blkPos;                            /* 当前块内样本计数 */
    float    blkMax;                            /* 当前块最大值 */
    float    blkMin;                            /* 当前块最小值 */
    float    blkMaxArr[ECG_HR_BLK_NUM];         /* 块最大值环形缓冲 */
    float    blkMinArr[ECG_HR_BLK_NUM];         /* 块最小值环形缓冲 */
    uint8_t  blkPtr;                            /* 环形块写指针 */
    uint8_t  blkValid;                          /* 已提交的有效块数(<=32) */
    float    winMax;                            /* 当前窗最大值(提交时刷新) */
    float    winMin;                            /* 当前窗最小值(提交时刷新) */
    uint8_t  sigValid;                          /* 窗峰峰值是否达标(信号存在) */

    /* ---- 峰检测状态机 ---- */
    uint8_t  peakActive;                        /* 是否在跟踪候选峰 */
    float    peakVal;                           /* 候选峰幅值 */
    uint32_t peakPos;                           /* 候选峰位置(最后创新高处) */
    uint16_t fallCnt;                           /* 峰后回落计数 */
    uint16_t refractory;                        /* 不应期倒计时(样本) */

    /* ---- RR 与心率 ---- */
    uint32_t sampleIdx;                         /* 累计样本序号 */
    uint32_t lastPeakIdx;                       /* 上一个确认峰位置 */
    uint8_t  hasLastPeak;                       /* 是否已有参考峰 */
    uint16_t rrArr[ECG_HR_MAX_RR];              /* 最近 RR 环形缓冲(样本数) */
    uint8_t  rrCnt;                             /* 有效 RR 个数 */
    uint8_t  rrPtr;                             /* RR 环形写指针 */
    uint16_t medRR;                             /* R-R 中位数(诊断用) */
    uint16_t peakCount;                         /* 累计确认峰数(诊断用) */
    int16_t  bpm;                               /* 最新心率; 0=无效 */
} ecg_heart_t;

void    ecg_heart_init(ecg_heart_t *h);
int16_t ecg_heart_step(ecg_heart_t *h, float x);

#endif /* ECG_HEART_H */
