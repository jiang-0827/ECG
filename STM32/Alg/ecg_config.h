#ifndef ECG_CONFIG_H
#define ECG_CONFIG_H

/* ============================================================================
 * ECG_CONFIG  监护型心电处理系统 —— 物理量与算法指标的唯一定义处
 *
 * 对应 MATLAB ：EcgMcuSim/ecg_config.m（逐字段一一对应；本文件即 ecg_config.h）
 * 工程准则    ：凡与"真实世界"耦合的数字（采样率/量程/指标/阈值/打印节流）
 *               只允许出现在本文件。算法模块里再出现硬编码数字，就是移植期
 *               的定时炸弹。
 *
 * 对应硬件 ：
 *   前端 = 自建心电模拟板（TL062 仪放 + LMV358 有源滤波 + LMV324 导联判决，
 *          Uref = 1.65V 中点偏置，输出 ECG / LEAD_OFF / RA / LA 为模拟量，
 *          板载电荷泵产生 -5V 供 TL062 使用；板上无 ADC、无 MCU、无 USB 串口）
 *   MCU  = 立创·天空星 STM32F407VET6（Cortex-M4F @168MHz，单精度硬件 FPU）
 *
 * 标注 [实测] 的字段是占位值，必须由你测量原理图后回填，否则误差折算不成立。
 * 说明：MATLAB 侧 single 仿真开关（cfg.filt.useSingle）在 C 侧恒等价于 true
 *       （本工程所有滤波运算均为 float），故不再以宏形式出现。
 *       仿真激励段（cfg.sim.*）属于 MATLAB 测试脚本配置，不参与固件移植。
 * ==========================================================================*/

/* ================= 采样与硬件（M1/M3）================= */
#define ECG_FS                  500.0f      /* 采样率 SPS，由 TIM2 TRGO 精确触发 */
#define ECG_T                   (1.0f / ECG_FS)  /* 2 ms/样本 → 168MHz 下 336000 cycle 预算 */

#define ECG_ADC_BITS            12
#define ECG_ADC_FULL            4095u                        /* 2^12 - 1 */
#define ECG_ADC_VREF            3.3f                         /* [实测] VREF+ 必须与 VDDA 同源 */
#define ECG_ADC_VBIAS           1.65f                        /* 原理图 Uref / TP9 */
#define ECG_ADC_BIAS_CODE       2048u                        /* round(1.65/3.3*4095) */
#define ECG_ADC_UV_PER_LSB_RAW  (ECG_ADC_VREF / (float)ECG_ADC_FULL * 1e6f)  /* 引脚端 ≈806 μV/LSB */
#define ECG_ADC_GAIN_FE         100.0f                       /* [实测] 前端总增益 V/V */
#define ECG_ADC_UV_PER_LSB      (ECG_ADC_UV_PER_LSB_RAW / ECG_ADC_GAIN_FE)   /* 电极端 μV/LSB */

/* ================= 滤波指标（监护型 0.5-40Hz）（M5）================= */
#define ECG_FILT_BIAS_EN        1u     /* 先扣 1.65V 直流（整数相减，零相位、零代价） */
#define ECG_FILT_HP_EN          0u     /* 数字高通：原理图疑已含 ~0.3-1Hz 模拟高通 → 默认关，实测再定 */
#define ECG_FILT_FHP            0.5f   /* Hz，重新生成系数时生效（gen_ecg_coeffs.m 读此值） */
#define ECG_FILT_NOTCH_EN       1u     /* 50Hz 陷波开关 */
#define ECG_FILT_FNOTCH         50.0f  /* Hz 工频 */
#define ECG_FILT_NOTCH_BETA     0.96f  /* 极点半径 → 3dB 缺口宽 ≈ 3.3*(1-beta)*Fs/pi ≈ 21.0 Hz */
#define ECG_FILT_FPASS          40.0f  /* Hz 通带上限（监护型） */
#define ECG_FILT_FSTOP          47.0f  /* Hz 阻带起点：必须 ≤49Hz，否则电网 ±1Hz 偏差漏进通带 */
#define ECG_FILT_AST_DB         80.0f  /* dB FIR 阻带衰减 */

/* ================= 心率与统计窗（M6/M7）=================
 * 注意：心率检测与异常判据模块（M6/M7/M9）MATLAB 侧尚未给出实现文件，
 *       本块配置先行固化，待对应 .c 模块开发时直接取用，勿改数值语义。 */
#define ECG_HR_WIN_LEN          2048u  /* 自适应阈值统计窗 = 4.096 s（对应原工程 MAX_X_CNT） */
#define ECG_HR_RR_MIN           250u   /* 不应期 0.5 s（= 原工程 findpeaks 的 MinPeakDistance） */
#define ECG_HR_PEAK_MARGIN      200    /* 阈值 = 窗内最大值 - 此值 [实测] 必须按"滤波后"幅值重标 */
#define ECG_HR_ABS_MIN          150    /* 窗内摆幅小于此值 → 判信号丢失，不输出心率 [实测] */
#define ECG_HR_MAX_RR           8u     /* 参与中值的最近 RR 个数（一个 4.1s 窗最多 5~7 个） */
#define ECG_HR_HR_MIN           30     /* bpm 合法下限（原工程用 0，监护场景太松） */
#define ECG_HR_HR_MAX           250    /* bpm 合法上限（原工程用 300） */
#define ECG_DET_BLK_LEN         64u    /* 滑动窗最大值分块长度：2048/64 = 32 块 */
#define ECG_DET_CONFIRM_FALL    3u     /* 连续 N 样本不创新高 → 确认 R 峰（代价：N*2ms 判决延迟） */

/* ================= 异常判据（M7/M9）================= */
#define ECG_LO_THR_CODE         2000u  /* [实测] 正常≈20mV(25码), 脱落≈3.0V(3723码), 取中点判决 */
#define ECG_LO_DEBOUNCE         50u    /* 连续 50 样本(100ms)成立才切状态，防抖 */
#define ECG_STUCK_REPEAT        50u    /* 连续 50 个完全相同码值 → 采样链路冻结 */

/* ================= 调试输出节流（M8）================= */
#define ECG_DBG_SAMPLE_DIV      5u     /* 每 5 样本打一行样本级日志 → 100 行/s */
#define ECG_DBG_SUMMARY_DIV     250u   /* 每 250 样本(0.5s) 打一行摘要 */
#define ECG_DBG_UART_BAUD       115200u /* 用于反算打印带宽占用是否吃满串口 */

#endif /* ECG_CONFIG_H */
